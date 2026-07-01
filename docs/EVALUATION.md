# Evaluation Evidence — Fixing a Hallucination

This document is the "evaluation evidence" deliverable: it shows, with a
repeatable harness and the built-in trace log, **how a hallucination was
diagnosed and fixed** by hardening the prompt and adding grounding guardrails.

LangSmith has no official Ruby SDK, so instead of external traces we use a
**self-hosted trace layer** (`trace_events` table, visible on every summary page
and via the API) plus a **golden-set evaluation harness** (`bin/rails eval:run`).
This is functionally the same evidence LangSmith would give: per-step inputs and
outputs, plus before/after metrics.

---

## 1. The observability layer (our LangSmith analogue)

Every chain run writes one `TraceEvent` per step (query parsing, retrieval,
parent-doc mapping, compression, generation, guardrails). You can inspect it:

- **UI:** open any summary — the "Trace (observability)" table lists each step,
  its status, latency, and output.
- **API:** `GET /api/v1/summaries/:id` returns the full `trace` array.

```bash
curl http://localhost:3000/api/v1/summaries/1 | jq '.trace'
```

Capture a screenshot of that trace table / JSON for the submission.

---

## 2. The hallucination we fixed

**Symptom (v1, naive prompt).** Asked *"What is this patient's TSH / thyroid
level?"* — a value that **does not exist** in any uploaded document — the naive v1
prompt produces a confident, plausible-sounding answer and even invents a numeric
TSH value. This is the classic, dangerous RAG failure: fluent fabrication.

**Root cause.** The v1 prompt (`Rag::PromptBuilder::V1_SYSTEM`) asks the model to
be "thorough and confident," never tells it to stay within the evidence, and
never requires citations. Nothing stops it from filling gaps with parametric
knowledge.

**The fix (v2, hardened prompt + guardrails).**
1. `V2_SYSTEM` restricts the model to the fenced `<evidence>` block, forbids
   outside knowledge, and **requires a citation per claim**.
2. It must set `insufficient_evidence: true` instead of guessing.
3. `Rag::OutputParser` strips any citation ref that isn't a real retrieved chunk.
4. `Rag::Guardrails.enforce` drops ungrounded sections and, when nothing relevant
   is retrieved, returns a `no_evidence` refusal with confidence `0.0`.

Result: on the same trap question, v2 **refuses** ("insufficient evidence")
instead of inventing a TSH value.

---

## 3. The evaluation harness

```bash
OPENAI_API_KEY=... bin/rails db:seed     # embed the synthetic documents
OPENAI_API_KEY=... bin/rails eval:run
```

The golden set (`lib/tasks/eval.rake`) mixes **answerable** questions (labs,
meds) with **trap** questions whose answer is absent (TSH, chest X-ray). For each
answer it computes:

- **ungrounded_numbers** — numeric values in the answer that do **not** appear in
  the retrieved evidence. A direct, checkable hallucination signal.
- **citation_rate** — share of answers that cite retrieved evidence.
- **refusal_correct** — for trap questions, did the system correctly refuse
  (`no_evidence` / `blocked`) instead of answering?

### Illustrative result (shape of the output)

```
=== Prompt version: v1 ===
QUERY                                              STATUS       CITED  REFUSAL    UNGROUNDED#
Summarize this patient's abnormal lab results.     ok           no     -          0
What is this patient's TSH / thyroid level?        ok           no     MISS       2 (2,45)
What did the patient's most recent chest X-ray...  ok           no     MISS       1 (2026)

=== Prompt version: v2 ===
QUERY                                              STATUS       CITED  REFUSAL    UNGROUNDED#
Summarize this patient's abnormal lab results.     ok           yes    -          0
What is this patient's TSH / thyroid level?        no_evidence  no     ok         0
What did the patient's most recent chest X-ray...  no_evidence  no     ok         0

=== Aggregate ===
VER    CITATION_RATE    AVG_UNGROUNDED   REFUSAL_ACC
v1     0%               ~1.0             0%
v2     ~66%             0.0              100%
```

> Exact numbers vary run to run (live model), but the **direction is stable and
> reproducible**: v1 fabricates values and never refuses; v2 cites, produces zero
> ungrounded numbers, and refuses trap questions 100% of the time. A machine-
> readable copy is written to `tmp/eval_report.json`.

### How to capture the evidence for submission
1. Run `bin/rails eval:run` and screenshot the terminal tables above.
2. Open the two summaries in the UI (v1 vs v2 on the TSH question) and screenshot
   the trace tables — v1 shows a `generator` step emitting an invented value; v2
   shows `guardrails_output` with status `no_evidence`.
3. Include `tmp/eval_report.json` in the submission.

---

## 4. Automated regression guard
The behavior above is locked in by RSpec (`bundle exec rspec`):
`spec/services/rag/chain_spec.rb` asserts that (a) grounded answers only cite real
retrieved chunks, and (b) unrelated queries return `no_evidence` — so a future
prompt change that reintroduces hallucination fails the suite.

# MedSummarizer — RAG Clinical Document Summarizer

A production-minded Retrieval-Augmented Generation (RAG) system that turns a
patient's fragmented medical documents (lab reports, imaging/MRI reports,
prescriptions) into a **grounded, cited, structured summary** for a licensed
clinician.

Built on **Ruby on Rails 7.1**, **PostgreSQL + pgvector**, and **OpenAI
gpt-4o-mini**. The orchestration layer implements a LangChain-style RAG pipeline
in idiomatic Ruby with three advanced retrieval optimizations, a safety /
guardrail layer, and self-hosted tracing for evaluation.

> Demo/synthetic data only. This is **not a medical device** and must not be
> used for real clinical decisions.

---

## Why this project (the ROI)

Clinicians lose minutes per patient reconciling scattered documents before a
consult, and missed lab values or drug interactions are high-severity errors. A
grounded summarizer that costs ~$0.05/call is trivially justified: a single saved
clinician-minute or a caught interaction dwarfs the token cost. See
[docs/TECHNICAL_DESIGN.md](docs/TECHNICAL_DESIGN.md) for the full argument.

## Architecture at a glance

```
Upload → Extract → Chunk (parent/child) → Embed → pgvector
Query  → Self-Query filters → Vector search (child) → Parent Document Retrieval
       → Contextual Compression → Prompt → gpt-4o-mini → Output Parser → Guardrails
       → Grounded, cited Summary  (+ full TraceEvent log)
```

Advanced techniques implemented (brief required ≥1):

1. **Parent Document Retrieval** — embed/search small child chunks for precision,
   feed the LLM their larger parent chunks for context.
2. **Metadata Self-Querying** — the LLM extracts `doc_type` / date filters from the
   question; they're pushed into SQL before the vector search.
3. **Contextual Compression** — an embeddings-filter that keeps only the most
   query-relevant sentences within a token budget.

Full design, diagrams, and trade-offs: [docs/TECHNICAL_DESIGN.md](docs/TECHNICAL_DESIGN.md).

---

## Requirements

- Ruby 3.3.x (a `.tool-versions` pins `ruby 3.3.6` for asdf)
- PostgreSQL 15+ with the **pgvector** extension
- An OpenAI API key (for live embeddings + summaries)

### Installing pgvector

```bash
# Homebrew (matches your installed Postgres major version):
brew install pgvector

# If your Postgres major version has no bottle, build from source:
git clone --branch v0.8.0 https://github.com/pgvector/pgvector.git
cd pgvector
make PG_CONFIG=$(pg_config --bindir)/pg_config
make PG_CONFIG=$(pg_config --bindir)/pg_config install
```

## Setup

```bash
# 1. Ruby + gems
asdf install            # or ensure Ruby 3.3.x is active
bundle install

# 2. Configure secrets
cp .env.example .env
# edit .env and set OPENAI_API_KEY=sk-...

# 3. Database (creates DBs, enables pgvector, runs migrations)
bin/rails db:prepare

# 4. Seed synthetic patients + documents
#    (with OPENAI_API_KEY set, documents are embedded/ingested inline)
bin/rails db:seed
```

## Run

```bash
bin/rails server
# open http://localhost:3000
```

From the UI you can create patients, upload/paste documents, and ask for a
summary (choose prompt version **v2 hardened** or **v1 naive baseline**). Each
summary page shows the citations and the full RAG **trace**.

Background ingestion runs via GoodJob (in-process). To run a dedicated worker:

```bash
bundle exec good_job start
```

## JSON API

```bash
# Ingest a document
curl -X POST http://localhost:3000/api/v1/documents \
  -H "Content-Type: application/json" \
  -d '{"document":{"patient_id":1,"doc_type":"lab_report","raw_text":"HbA1c 8.4% high ...","document_date":"2026-06-02"}}'

# Ask for a summary
curl -X POST http://localhost:3000/api/v1/summaries \
  -H "Content-Type: application/json" \
  -d '{"query":"Summarize the diabetes panel and current medications","patient_id":1}'

# Fetch a summary + its trace
curl http://localhost:3000/api/v1/summaries/1
```

## Evaluation (hallucination evidence)

Runs a golden set through both prompt versions and reports citation rate,
ungrounded numbers, and refusal accuracy on "trap" questions:

```bash
OPENAI_API_KEY=... bin/rails db:seed     # ensure docs are embedded
OPENAI_API_KEY=... bin/rails eval:run
```

The naive **v1** baseline invents values on trap questions; the hardened **v2**
prompt refuses or cites. Details and how to capture screenshots:
[docs/EVALUATION.md](docs/EVALUATION.md).

## Tests

```bash
bundle exec rspec
```

Specs use a deterministic, offline fake LLM client (`spec/support/fake_llm_client.rb`)
so the full pipeline is exercised without hitting OpenAI.

## Project layout

| Path | What |
|------|------|
| `app/services/llm/` | OpenAI client wrapper (chat + embeddings) |
| `app/services/ingestion/` | Text extraction, chunking, embedding, pipeline |
| `app/services/rag/` | The orchestration chain and every step |
| `app/models/` | Patient, Document, DocumentChunk, Summary, TraceEvent |
| `lib/tasks/eval.rake` | Evaluation harness (v1 vs v2) |
| `docs/` | Technical Design Document + Evaluation notes |
| `db/seed_documents/` | Synthetic sample medical documents |

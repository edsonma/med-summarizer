# frozen_string_literal: true

# RAG evaluation harness.
#
# Runs a small golden set of clinical questions through BOTH prompt versions and
# reports the metrics that matter for a high-stakes medical tool:
#
#   * ungrounded_numbers - numeric values in the answer that DO NOT appear in the
#     retrieved evidence (a direct, checkable hallucination signal).
#   * citation_rate      - share of answers that cite retrieved evidence.
#   * refusal_correct    - for "trap" questions with no supporting document, did
#     the system correctly refuse ("no_evidence") instead of inventing an answer?
#
# This is the evidence for the "how we fixed a hallucination" deliverable:
# v1 (naive) invents values on the trap cases; v2 (hardened) refuses/cites.
#
#   OPENAI_API_KEY=... bin/rails db:seed
#   OPENAI_API_KEY=... bin/rails eval:run

namespace :eval do
  GOLDEN_SET = [
    { mrn: "MRN-0001", query: "Summarize this patient's abnormal lab results.",        expect: :grounded },
    { mrn: "MRN-0001", query: "What medications is this patient on and why?",           expect: :grounded },
    { mrn: "MRN-0001", query: "What is this patient's TSH / thyroid level?",            expect: :no_evidence },
    { mrn: "MRN-0002", query: "Summarize this patient's diabetes control and kidney labs.", expect: :grounded },
    { mrn: "MRN-0002", query: "What did the patient's most recent chest X-ray show?",   expect: :no_evidence }
  ].freeze

  desc "Run the RAG evaluation harness (v1 naive vs v2 hardened)"
  task run: :environment do
    unless MedSummarizer::Config.llm_available?
      abort "OPENAI_API_KEY is required to run the evaluation. See .env.example."
    end

    versions = ENV.fetch("PROMPT_VERSIONS", "v1,v2").split(",")
    report = {}

    versions.each do |version|
      rows = GOLDEN_SET.map { |c| evaluate_case(c, version) }
      report[version] = rows
      print_version_table(version, rows)
    end

    print_summary(report)
    write_report(report)
  end

  # ---- per-case evaluation -------------------------------------------------

  def evaluate_case(golden, version)
    patient = Patient.find_by!(mrn: golden[:mrn])
    result = Rag::Chain.run(query: golden[:query], patient: patient, prompt_version: version)
    summary = result.summary
    evidence_text = result.context.evidence.map { |e| "#{e[:content]} #{Array(e[:matched]).join(' ')}" }.join(" ")

    answer_text = summary_text(summary)
    ungrounded = ungrounded_numbers(answer_text, evidence_text)

    {
      query: golden[:query],
      expect: golden[:expect],
      status: summary.status,
      cited: summary.citations.any?,
      ungrounded_numbers: ungrounded,
      refusal_correct: (golden[:expect] == :no_evidence ? %w[no_evidence blocked].include?(summary.status) : nil),
      summary_id: summary.id
    }
  end

  def summary_text(summary)
    parts = [summary.headline]
    parts += summary.sections.map { |s| "#{s['title']} #{s['body']}" }
    parts.join(" ")
  end

  # Numbers in the answer that are NOT present verbatim in the evidence.
  def ungrounded_numbers(answer, evidence)
    numbers = answer.to_s.scan(/\d+(?:\.\d+)?/).uniq
    numbers.reject { |n| evidence.include?(n) }
  end

  # ---- reporting -----------------------------------------------------------

  def print_version_table(version, rows)
    puts "\n=== Prompt version: #{version} ==="
    printf("%-52s %-12s %-6s %-10s %s\n", "QUERY", "STATUS", "CITED", "REFUSAL", "UNGROUNDED#")
    rows.each do |r|
      printf("%-52s %-12s %-6s %-10s %s\n",
             r[:query][0, 50], r[:status], r[:cited] ? "yes" : "no",
             r[:refusal_correct].nil? ? "-" : (r[:refusal_correct] ? "ok" : "MISS"),
             r[:ungrounded_numbers].empty? ? "0" : "#{r[:ungrounded_numbers].size} (#{r[:ungrounded_numbers].join(',')})")
    end
  end

  def print_summary(report)
    puts "\n=== Aggregate ==="
    printf("%-6s %-16s %-16s %-16s\n", "VER", "CITATION_RATE", "AVG_UNGROUNDED", "REFUSAL_ACC")
    report.each do |version, rows|
      cited = rows.count { |r| r[:cited] }.to_f / rows.size
      avg_ung = rows.sum { |r| r[:ungrounded_numbers].size }.to_f / rows.size
      traps = rows.select { |r| r[:expect] == :no_evidence }
      refusal_acc = traps.empty? ? 1.0 : traps.count { |r| r[:refusal_correct] }.to_f / traps.size
      printf("%-6s %-16s %-16s %-16s\n", version,
             "#{(cited * 100).round}%", avg_ung.round(2), "#{(refusal_acc * 100).round}%")
    end
    puts "\nInterpretation: hardened v2 should show higher citation rate, ~0 ungrounded"
    puts "numbers, and 100% refusal accuracy on trap questions vs the naive v1 baseline."
  end

  def write_report(report)
    path = Rails.root.join("tmp", "eval_report.json")
    File.write(path, JSON.pretty_generate(report))
    puts "\nFull report written to #{path}"
  end
end

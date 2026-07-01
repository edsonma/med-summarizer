# frozen_string_literal: true

# Seeds the demo with two SYNTHETIC patients and their documents.
#
# Documents are ingested inline when an OPENAI_API_KEY is present (so the vector
# store is populated and you can immediately run summaries). Without a key, the
# documents are still created but left "pending" -- run the ingestion later once
# a key is configured.

SEED_DIR = Rails.root.join("db", "seed_documents")

MANIFEST = [
  { name: "Jane Doe", mrn: "MRN-0001", docs: [
    { file: "jane_doe_lab_report.txt",   doc_type: "lab_report",     date: "2026-05-12" },
    { file: "jane_doe_prescription.txt", doc_type: "prescription",   date: "2026-05-13" },
    { file: "jane_doe_mri_report.txt",   doc_type: "imaging_report", date: "2026-04-28" }
  ] },
  { name: "John Smith", mrn: "MRN-0002", docs: [
    { file: "john_smith_lab_report.txt",   doc_type: "lab_report",   date: "2026-06-02" },
    { file: "john_smith_prescription.txt", doc_type: "prescription", date: "2026-06-03" }
  ] }
].freeze

ingest_inline = MedSummarizer::Config.llm_available?
puts ingest_inline ? "OPENAI_API_KEY detected: ingesting documents inline." :
                     "No OPENAI_API_KEY: creating documents as 'pending' (ingest later)."

MANIFEST.each do |entry|
  patient = Patient.find_or_create_by!(mrn: entry[:mrn]) { |p| p.name = entry[:name] }

  entry[:docs].each do |doc_spec|
    text = File.read(SEED_DIR.join(doc_spec[:file]))
    document = patient.documents.find_or_initialize_by(filename: doc_spec[:file])
    document.assign_attributes(
      doc_type: doc_spec[:doc_type],
      raw_text: text,
      document_date: doc_spec[:date],
      status: "pending"
    )
    document.save!

    if ingest_inline
      Ingestion::Pipeline.call(document)
      puts "  ingested #{patient.name} / #{doc_spec[:file]}"
    else
      puts "  created (pending) #{patient.name} / #{doc_spec[:file]}"
    end
  end
end

puts "Seed complete: #{Patient.count} patients, #{Document.count} documents, #{DocumentChunk.count} chunks."

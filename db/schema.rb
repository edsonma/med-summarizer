# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_07_01_030005) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "vector"

  create_table "document_chunks", force: :cascade do |t|
    t.bigint "document_id", null: false
    t.bigint "parent_id"
    t.string "kind", null: false, comment: "parent | child"
    t.integer "position", default: 0, null: false
    t.text "content", null: false
    t.vector "embedding", limit: 1536, comment: "text-embedding-3-small; only populated for child chunks"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_id"], name: "index_document_chunks_on_document_id"
    t.index ["embedding"], name: "index_document_chunks_on_embedding", opclass: :vector_cosine_ops, where: "((kind)::text = 'child'::text)", using: :hnsw
    t.index ["kind"], name: "index_document_chunks_on_kind"
    t.index ["metadata"], name: "index_document_chunks_on_metadata", using: :gin
    t.index ["parent_id"], name: "index_document_chunks_on_parent_id"
  end

  create_table "documents", force: :cascade do |t|
    t.bigint "patient_id", null: false
    t.string "doc_type", null: false, comment: "lab_report | imaging_report | prescription | clinical_note"
    t.string "filename"
    t.text "raw_text"
    t.jsonb "metadata", default: {}, null: false
    t.string "status", default: "pending", null: false, comment: "pending | processing | ingested | failed"
    t.datetime "document_date", comment: "Clinical date of the document (used for date-scoped self-querying)"
    t.datetime "ingested_at"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["doc_type"], name: "index_documents_on_doc_type"
    t.index ["metadata"], name: "index_documents_on_metadata", using: :gin
    t.index ["patient_id"], name: "index_documents_on_patient_id"
    t.index ["status"], name: "index_documents_on_status"
  end

  create_table "good_job_batches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.jsonb "serialized_properties"
    t.text "on_finish"
    t.text "on_success"
    t.text "on_discard"
    t.text "callback_queue_name"
    t.integer "callback_priority"
    t.datetime "enqueued_at"
    t.datetime "discarded_at"
    t.datetime "finished_at"
    t.datetime "jobs_finished_at"
  end

  create_table "good_job_executions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "active_job_id", null: false
    t.text "job_class"
    t.text "queue_name"
    t.jsonb "serialized_params"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.text "error"
    t.integer "error_event", limit: 2
    t.text "error_backtrace", array: true
    t.uuid "process_id"
    t.interval "duration"
    t.index ["active_job_id", "created_at"], name: "index_good_job_executions_on_active_job_id_and_created_at"
    t.index ["process_id", "created_at"], name: "index_good_job_executions_on_process_id_and_created_at"
  end

  create_table "good_job_processes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "state"
    t.integer "lock_type", limit: 2
  end

  create_table "good_job_settings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "key"
    t.jsonb "value"
    t.index ["key"], name: "index_good_job_settings_on_key", unique: true
  end

  create_table "good_jobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "queue_name"
    t.integer "priority"
    t.jsonb "serialized_params"
    t.datetime "scheduled_at"
    t.datetime "performed_at"
    t.datetime "finished_at"
    t.text "error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "active_job_id"
    t.text "concurrency_key"
    t.text "cron_key"
    t.uuid "retried_good_job_id"
    t.datetime "cron_at"
    t.uuid "batch_id"
    t.uuid "batch_callback_id"
    t.boolean "is_discrete"
    t.integer "executions_count"
    t.text "job_class"
    t.integer "error_event", limit: 2
    t.text "labels", array: true
    t.uuid "locked_by_id"
    t.datetime "locked_at"
    t.integer "lock_type", limit: 2
    t.index ["active_job_id", "created_at"], name: "index_good_jobs_on_active_job_id_and_created_at"
    t.index ["batch_callback_id"], name: "index_good_jobs_on_batch_callback_id", where: "(batch_callback_id IS NOT NULL)"
    t.index ["batch_id"], name: "index_good_jobs_on_batch_id", where: "(batch_id IS NOT NULL)"
    t.index ["concurrency_key", "created_at"], name: "index_good_jobs_on_concurrency_key_and_created_at"
    t.index ["concurrency_key"], name: "index_good_jobs_on_concurrency_key_when_unfinished", where: "(finished_at IS NULL)"
    t.index ["created_at"], name: "index_good_jobs_on_created_at"
    t.index ["cron_key", "created_at"], name: "index_good_jobs_on_cron_key_and_created_at_cond", where: "(cron_key IS NOT NULL)"
    t.index ["cron_key", "cron_at"], name: "index_good_jobs_on_cron_key_and_cron_at_cond", unique: true, where: "(cron_key IS NOT NULL)"
    t.index ["finished_at"], name: "index_good_jobs_jobs_on_finished_at_only", where: "(finished_at IS NOT NULL)"
    t.index ["finished_at"], name: "index_good_jobs_on_discarded", order: :desc, where: "((finished_at IS NOT NULL) AND (error IS NOT NULL))"
    t.index ["id"], name: "index_good_jobs_on_unfinished_or_errored", where: "((finished_at IS NULL) OR (error IS NOT NULL))"
    t.index ["job_class"], name: "index_good_jobs_on_job_class"
    t.index ["labels"], name: "index_good_jobs_on_labels", where: "(labels IS NOT NULL)", using: :gin
    t.index ["locked_by_id"], name: "index_good_jobs_on_locked_by_id", where: "(locked_by_id IS NOT NULL)"
    t.index ["priority", "created_at"], name: "index_good_job_jobs_for_candidate_lookup", where: "(finished_at IS NULL)"
    t.index ["priority", "created_at"], name: "index_good_jobs_jobs_on_priority_created_at_when_unfinished", order: { priority: "DESC NULLS LAST" }, where: "(finished_at IS NULL)"
    t.index ["priority", "scheduled_at", "id"], name: "index_good_jobs_for_candidate_dequeue_unlocked", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["priority", "scheduled_at", "id"], name: "index_good_jobs_on_priority_scheduled_at_unfinished", where: "(finished_at IS NULL)"
    t.index ["priority", "scheduled_at"], name: "index_good_jobs_on_priority_scheduled_at_unfinished_unlocked", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["queue_name", "scheduled_at", "id"], name: "index_good_jobs_on_queue_name_priority_scheduled_at_unfinished", where: "(finished_at IS NULL)"
    t.index ["queue_name", "scheduled_at"], name: "index_good_jobs_on_queue_name_and_scheduled_at", where: "(finished_at IS NULL)"
    t.index ["queue_name"], name: "index_good_jobs_on_queue_name"
    t.index ["scheduled_at", "queue_name"], name: "index_good_jobs_on_scheduled_at_and_queue_name"
    t.index ["scheduled_at"], name: "index_good_jobs_on_scheduled_at", where: "(finished_at IS NULL)"
  end

  create_table "patients", force: :cascade do |t|
    t.string "mrn", null: false, comment: "Medical Record Number (synthetic in this demo)"
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["mrn"], name: "index_patients_on_mrn", unique: true
  end

  create_table "summaries", force: :cascade do |t|
    t.bigint "patient_id"
    t.text "query", null: false
    t.jsonb "content", default: {}, null: false, comment: "Structured summary (sections, citations, flags)"
    t.string "model"
    t.string "prompt_version"
    t.integer "prompt_tokens", default: 0
    t.integer "completion_tokens", default: 0
    t.integer "latency_ms", default: 0
    t.float "confidence", comment: "0.0-1.0; low when evidence is weak/absent"
    t.string "status", default: "ok", null: false, comment: "ok | no_evidence | blocked | error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["patient_id"], name: "index_summaries_on_patient_id"
    t.index ["status"], name: "index_summaries_on_status"
  end

  create_table "trace_events", force: :cascade do |t|
    t.bigint "summary_id"
    t.string "trace_id", null: false, comment: "Groups all events of a single chain run"
    t.string "step", null: false, comment: "query_parser | retriever | compressor | llm | output_parser | guardrails"
    t.integer "sequence", default: 0, null: false
    t.jsonb "input", default: {}, null: false
    t.jsonb "output", default: {}, null: false
    t.integer "tokens", default: 0
    t.integer "latency_ms", default: 0
    t.string "status", default: "ok"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["summary_id"], name: "index_trace_events_on_summary_id"
    t.index ["trace_id", "sequence"], name: "index_trace_events_on_trace_id_and_sequence"
    t.index ["trace_id"], name: "index_trace_events_on_trace_id"
  end

  add_foreign_key "document_chunks", "document_chunks", column: "parent_id"
  add_foreign_key "document_chunks", "documents"
  add_foreign_key "documents", "patients"
  add_foreign_key "summaries", "patients"
  add_foreign_key "trace_events", "summaries"
end

source "https://rubygems.org"

ruby "3.3.6"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 7.1.5"

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem "sprockets-rails"

# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"

# --- Medical Document Summarizer (RAG) dependencies ---
# pgvector integration for ActiveRecord (vector similarity search)
gem "neighbor", "~> 0.5"
# OpenAI client (chat completions + embeddings)
gem "ruby-openai", "~> 7.3"
# Postgres-backed background jobs (no Redis needed) for ingestion pipeline
gem "good_job", "~> 4.0"
# Text extraction from uploaded PDF documents (labs, prescriptions, imaging reports)
gem "pdf-reader", "~> 2.12"
# Load ENV vars (OPENAI_API_KEY, etc.) from .env in development/test
gem "dotenv-rails", groups: %i[development test]

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ]
  # Testing framework + fixtures/mocks
  gem "rspec-rails", "~> 7.1"
  gem "webmock", "~> 3.24"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Add speed badges [https://github.com/MiniProfiler/rack-mini-profiler]
  # gem "rack-mini-profiler"

  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"
end


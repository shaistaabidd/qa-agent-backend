source "https://rubygems.org"

ruby file: ".ruby-version"

# Core -------------------------------------------------------------------
gem "bootsnap", require: false
gem "pg", "~> 1.6"
gem "puma", ">= 7.0"
gem "rails", "~> 8.1.4"
gem "tzinfo-data", platforms: %i[windows jruby]

# GraphQL API ------------------------------------------------------------
gem "apollo_upload_server", "~> 2.1"
gem "graphql", "~> 2.6"

# Authentication (has_secure_password) and authorization -----------------
gem "action_policy", "~> 0.7"
gem "bcrypt", "~> 3.1"

# Background jobs (Sidekiq only) and cache --------------------------------
gem "redis", "~> 5.4"
gem "sidekiq", "~> 8.1"

# Feature flags -----------------------------------------------------------
gem "flipper", "~> 1.4"
gem "flipper-redis", "~> 1.4"
gem "flipper-ui", "~> 1.4"
# Phone validation and E.164 formatting (pinned: 0.10.28 was a day old when added).
gem "phonelib", "0.10.27"
# SMS through Twilio (official SDK); 7.12 was 9 days old when added.
gem "twilio-ruby", "~> 7.11.3"

# QA Agent domain ---------------------------------------------------------
# Run lifecycle state machine.
gem "aasm", "~> 6.0"
# Outbound calls to the agent worker and ClickUp.
gem "httparty", "~> 0.24"
# GitHub App authentication (RS256 app JWT) and the Contents API.
gem "jwt", "~> 3.2"
gem "octokit", "~> 10.0"

# Files ------------------------------------------------------------------
gem "active_storage_validations", "~> 4.1"
gem "aws-sdk-s3", "~> 1.200", require: false

# Pagination, audit trail, migration safety ------------------------------
gem "pagy", "~> 43.7"
gem "paper_trail", "~> 17.0"
gem "strong_migrations", "~> 2.8"

# HTTP hardening ---------------------------------------------------------
gem "rack-attack", "~> 6.8"
gem "rack-cors", "~> 3.0"

# Error tracking (no-op until SENTRY_DSN is set) -------------------------
gem "sentry-rails", "~> 7.1"
gem "sentry-ruby", "~> 7.1"

group :development, :test do
  gem "brakeman", require: false
  gem "bullet", "~> 8.3"
  gem "bundler-audit", require: false
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "dotenv-rails", "~> 3.1"
  gem "factory_bot_rails", "~> 6.5"
  gem "faker", "~> 3.5"
  gem "rspec-rails", "~> 8.0"
  gem "rubocop", require: false
  gem "rubocop-factory_bot", require: false
  gem "rubocop-graphql", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-rspec", require: false
  gem "rubocop-rspec_rails", require: false
end

group :development do
  # Browser inbox for development email at /letter_opener.
  gem "letter_opener_web", "~> 3.0"
end

group :test do
  gem "shoulda-matchers", "~> 7.0"
  gem "simplecov", require: false
  gem "webmock", "~> 3.25"
end

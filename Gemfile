source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.2.2'

gem 'rails', '~> 7.0.5'

# Rails 7.0's postgresql adapter calls JSON.generate with a `quirks_mode` kwarg
# that json >= 2.7 removed; pin to the last compatible release.
gem 'json', '~> 2.6.3'

# Use postgresql as the database for Active Record
gem 'pg', '~> 1.1'

# Use the Puma web server [https://github.com/puma/puma]
gem 'puma', '~> 5.0'

# Redis for Sidekiq / caching
gem 'redis'

# Password hashing for Devise
gem 'bcrypt', '~> 3.1.7'

# Auth
gem 'devise'
gem 'jwt'

# Business-logic layer (mirrors learnerpass-api's interactor pattern)
gem 'interactor', '~> 3.0'

# GraphQL API
gem 'graphql'

# Multipart file uploads through GraphQL mutations (screenshot evidence)
gem 'apollo_upload_server', '2.1.0'

# State machine for Run / ScopeFeature lifecycle
gem 'aasm'

# Background jobs
gem 'sidekiq', '~> 6.5'
gem 'sidekiq-cron'

# Pagination (offset-based, matches reference project convention)
gem 'kaminari'

# Evidence storage (screenshots, console logs)
gem 'aws-sdk-s3', '~> 1'

# GitHub App integration (contents:read only)
gem 'octokit'

# ClickUp REST client + agent-worker callbacks
gem 'httparty'

# CORS for the separately-hosted frontend
gem 'rack-cors'

# Env config (config/application.yml, matches learnerpass-api)
gem 'figaro'

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false

group :development, :test do
  gem 'debug', platforms: %i[mri mingw x64_mingw]
  gem 'factory_bot_rails'
  gem 'rspec-rails', '~> 5.0'
  gem 'rubocop', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false
  gem 'shoulda-matchers', '~> 5.0'
  gem 'simplecov', require: false
  gem 'webmock'
end

group :development do
  gem 'graphiql-rails'
end

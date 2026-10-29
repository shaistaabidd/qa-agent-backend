require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"

Bundler.require(*Rails.groups)

module QaAgentBackend
  class Application < Rails::Application
    config.load_defaults 8.1

    config.autoload_lib(ignore: %w[assets tasks])

    config.api_only = true
    config.time_zone = "UTC"

    # Background jobs run on Sidekiq only (Redis 7+). See CLAUDE.md.
    config.active_job.queue_adapter = :sidekiq
    config.active_job.enqueue_after_transaction_commit = true
    config.active_storage.variant_processor = :disabled

    config.x.app_name = ENV.fetch("APP_NAME", "QA Agent")
    config.x.frontend_url = ENV.fetch("FRONTEND_URL", "http://localhost:5173")
    config.x.cors_allowed_origins = ENV.fetch("CORS_ALLOWED_ORIGINS", "http://localhost:5173").split(",").map(&:strip)

    # SMS always go through Twilio. In development use Twilio's test credentials
    # (nothing is sent); production requires the live ones (see production.rb).
    config.x.sms = {
      account_sid: ENV.fetch("TWILIO_ACCOUNT_SID", nil),
      auth_token: ENV.fetch("TWILIO_AUTH_TOKEN", nil),
      from: ENV.fetch("TWILIO_FROM_NUMBER", nil),
      messaging_service_sid: ENV.fetch("TWILIO_MESSAGING_SERVICE_SID", nil)
    }

    # Sign in with Google. The API runs the whole OAuth redirect, so the frontend holds
    # no Google config. redirect_uri must be listed exactly in the Google OAuth client.
    config.x.google_oauth = {
      client_id: ENV.fetch("GOOGLE_CLIENT_ID", nil),
      client_secret: Rails.application.credentials.dig(:google, :client_secret) ||
                     ENV.fetch("GOOGLE_CLIENT_SECRET", nil),
      redirect_uri: ENV.fetch("GOOGLE_REDIRECT_URI",
                              "http://localhost:#{ENV.fetch("PORT", 3000)}/auth/google/callback"),
      # "true" also asks Google for phone and birthday (People API sensitive scopes, which need
      # Google's app verification before real users can grant them). Off: name, email and photo.
      people_details: ENV["GOOGLE_PEOPLE_DETAILS"] == "true"
    }

    config.x.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
    # Heroku Redis serves TLS with a self-signed certificate; set REDIS_SSL_VERIFY_NONE=true only there.
    config.x.redis[:ssl_params] = { verify_mode: OpenSSL::SSL::VERIFY_NONE } if ENV["REDIS_SSL_VERIFY_NONE"] == "true"
    config.cache_store = :redis_cache_store, config.x.redis

    config.generators do |g|
      g.orm :active_record
      g.test_framework :rspec, fixtures: false, view_specs: false, helper_specs: false, routing_specs: false
      g.fixture_replacement :factory_bot, dir: "spec/factories"
    end
  end
end

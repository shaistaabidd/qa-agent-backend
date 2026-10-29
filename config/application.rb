require_relative "boot"

require "rails"
require "uri"
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

    # QaProbe is required explicitly by its initializer (it installs middleware, which must not be
    # reloadable), so Zeitwerk stays away from it.
    config.autoload_lib(ignore: %w[assets tasks qa_probe.rb qa_probe])

    config.api_only = true
    config.time_zone = "UTC"

    # Background jobs run on Sidekiq only (Redis 7+). See CLAUDE.md.
    config.active_job.queue_adapter = :sidekiq
    config.active_job.enqueue_after_transaction_commit = true
    config.active_storage.variant_processor = :disabled

    # Role credentials are encrypted at rest. This must be set here: ActiveRecord reads it in its own
    # initializer, before config/initializers run. Production needs real keys (rails db:encryption:init);
    # development and test fall back to fixed throwaway ones so a fresh clone boots.
    encryption_key = ->(name) { Rails.env.production? ? ENV.fetch(name) : ENV.fetch(name, "local-#{name.downcase}") }
    config.active_record.encryption.primary_key = encryption_key.call("AR_ENCRYPTION_PRIMARY_KEY")
    config.active_record.encryption.deterministic_key = encryption_key.call("AR_ENCRYPTION_DETERMINISTIC_KEY")
    config.active_record.encryption.key_derivation_salt = encryption_key.call("AR_ENCRYPTION_KEY_DERIVATION_SALT")

    # Whether a project's target URL may be a local or private address. The worker browses these URLs,
    # so production refuses them unless ALLOW_PRIVATE_TARGETS=true (for example a staging app on a VPN).
    config.x.allow_private_targets = ENV.fetch("ALLOW_PRIVATE_TARGETS", (!Rails.env.production?).to_s) == "true"

    config.x.app_name = ENV.fetch("APP_NAME", "QA Agent")
    # The agent worker: where runs are dispatched, and the shared secrets for both directions.
    config.x.agent = {
      worker_base_url: ENV.fetch("AGENT_WORKER_BASE_URL", nil),
      worker_api_token: ENV.fetch("AGENT_WORKER_API_TOKEN", nil),
      api_token: ENV.fetch("AGENT_API_TOKEN", nil)
    }
    # The existing Heroku config vars from before the move onto the boilerplate (APP_BASE_URL, FRONTEND_ORIGINS,
    # EVIDENCE_S3_BUCKET) keep working. The boilerplate's own names (APP_HOST, CORS_ALLOWED_ORIGINS, S3_BUCKET,
    # FRONTEND_URL, ALLOWED_HOSTS) win when set, so nothing has to be renamed to deploy.
    #
    # app_host is "host" or "host:port" (what mailer URL options and the worker callback need), taken from
    # APP_HOST, else from the full URL in APP_BASE_URL.
    app_host_from_base_url = lambda do
      uri = URI.parse(ENV["APP_BASE_URL"].to_s)
      next unless uri.host

      uri.port == uri.default_port ? uri.host : "#{uri.host}:#{uri.port}"
    rescue URI::InvalidURIError
      nil
    end
    config.x.app_host = ENV["APP_HOST"].presence || app_host_from_base_url.call

    cors_origins = ENV["CORS_ALLOWED_ORIGINS"].presence || ENV["FRONTEND_ORIGINS"].presence
    config.x.cors_allowed_origins = (cors_origins || "http://localhost:5173").split(",").map(&:strip)
    config.x.frontend_url = ENV["FRONTEND_URL"].presence ||
                            (cors_origins ? config.x.cors_allowed_origins.first : "http://localhost:5173")
    config.x.s3_bucket = ENV["S3_BUCKET"].presence || ENV["EVIDENCE_S3_BUCKET"].presence

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

    # Heroku's Redis Cloud add-on provides REDISCLOUD_URL; locally and with other Redis providers it is REDIS_URL.
    config.x.redis = { url: ENV["REDISCLOUD_URL"].presence || ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
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

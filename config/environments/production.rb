require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false

  config.action_controller.perform_caching = true
  config.active_storage.service = :amazon

  # TLS terminates at the load balancer; every request is treated as HTTPS
  # and the health check stays reachable over plain HTTP.
  config.assume_ssl = true
  config.force_ssl = true
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  config.hosts = ENV.fetch("ALLOWED_HOSTS").split(",").map(&:strip)
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }

  config.log_tags = [:request_id]
  config.logger = ActiveSupport::TaggedLogging.logger($stdout)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.silence_healthcheck_path = "/up"

  config.active_support.report_deprecations = false

  config.action_mailer.perform_caching = false
  config.action_mailer.default_url_options = { host: ENV.fetch("APP_HOST"), protocol: "https" }
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: ENV.fetch("SMTP_ADDRESS"),
    port: ENV.fetch("SMTP_PORT", 587).to_i,
    user_name: ENV.fetch("SMTP_USERNAME"),
    password: ENV.fetch("SMTP_PASSWORD"),
    authentication: :plain,
    enable_starttls_auto: true
  }

  config.x.frontend_url = ENV.fetch("FRONTEND_URL")

  # SMS is opt-in: Twilio is only required at boot once SMS_ENABLED=true. Delivery is
  # still gated per user by the sms_enabled feature flag.
  if ENV["SMS_ENABLED"] == "true"
    config.x.sms = {
      account_sid: ENV.fetch("TWILIO_ACCOUNT_SID"),
      auth_token: ENV.fetch("TWILIO_AUTH_TOKEN"),
      from: ENV.fetch("TWILIO_FROM_NUMBER", nil),
      messaging_service_sid: ENV.fetch("TWILIO_MESSAGING_SERVICE_SID", nil)
    }
    if config.x.sms.values_at(:from, :messaging_service_sid).none?
      raise KeyError, "Set TWILIO_FROM_NUMBER or TWILIO_MESSAGING_SERVICE_SID"
    end
  end

  # Fail at boot, not on the first upload, when S3 isn't configured.
  ENV.fetch("S3_BUCKET")
  %w[AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY].each do |name|
    next if ENV[name].present?

    raise KeyError, "Set #{name} for production storage"
  end
  config.x.cors_allowed_origins = ENV.fetch("CORS_ALLOWED_ORIGINS").split(",").map(&:strip)

  config.i18n.fallbacks = true

  config.active_record.dump_schema_after_migration = false
  config.active_record.attributes_for_inspect = [:id]
end

require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.server_timing = true

  config.action_controller.perform_caching = false

  config.active_support.deprecation = :log
  config.active_record.migration_error = :page_load
  config.active_record.verbose_query_logs = true
  config.active_record.query_log_tags_enabled = true

  # Mail opens in a browser inbox at http://localhost:<port>/letter_opener.
  config.action_mailer.delivery_method = :letter_opener_web
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.perform_caching = false
  config.action_mailer.default_url_options = { host: ENV.fetch("APP_HOST", "localhost:3000") }

  config.active_job.verbose_enqueue_logs = true
  config.active_storage.service = :local

  config.i18n.raise_on_missing_translations = true

  config.after_initialize do
    Bullet.enable = true
    Bullet.bullet_logger = true
    Bullet.rails_logger = true
    Bullet.raise = true
  end
end

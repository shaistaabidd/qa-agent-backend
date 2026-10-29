require "active_support/core_ext/integer/time"

Rails.application.configure do
  # dotenv loads .env in test too: specs use fixed Twilio and Google credentials, never
  # .env's, and WebMock answers both APIs (spec/support/twilio_helper.rb, google_oauth_helper.rb).
  config.x.sms = { account_sid: "AC#{"0" * 32}", auth_token: "test-auth-token", from: "+15005550006",
                   messaging_service_sid: nil }
  config.x.google_oauth = { client_id: "test-client-id.apps.googleusercontent.com", client_secret: "test-client-secret",
                            redirect_uri: "http://api.example.test/auth/google/callback", people_details: true }

  # Flipper's test helper resets flags in a before hook, which runs after a spec's own
  # around hooks and so undoes them; spec/support/flipper_helper.rb resets them instead.
  config.flipper.test_help = false

  config.enable_reloading = false
  config.eager_load = ENV["CI"].present?
  config.consider_all_requests_local = true

  config.action_controller.perform_caching = false
  # A real store so throttling specs can count attempts.
  config.cache_store = :memory_store

  config.active_job.queue_adapter = :test
  config.active_storage.service = :test

  config.action_mailer.delivery_method = :test
  config.action_mailer.perform_caching = false
  config.action_mailer.default_url_options = { host: "www.example.com" }

  config.active_support.deprecation = :raise
  config.action_controller.raise_on_missing_callback_actions = true
  config.i18n.raise_on_missing_translations = true

  config.after_initialize do
    Bullet.enable = true
    Bullet.bullet_logger = true
    Bullet.raise = true
  end
end

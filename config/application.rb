require_relative 'boot'

require 'rails'
# Pick the frameworks you want:
require 'active_model/railtie'
require 'active_job/railtie'
require 'active_record/railtie'
require 'active_storage/engine'
require 'action_controller/railtie'
require 'action_mailer/railtie'
require 'action_mailbox/engine'
require 'action_text/engine'
require 'action_view/railtie'
require 'action_cable/engine'
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module QaAgentBackend
  class Application < Rails::Application
    config.active_record.query_log_tags_enabled = true
    config.active_record.query_log_tags = [
      # Rails query log tags:
      :application, :controller, :action, :job,
      # GraphQL-Ruby query log tags:
      {
        current_graphql_operation: -> { GraphQL::Current.operation_name },
        current_graphql_field: -> { GraphQL::Current.field&.path },
        current_dataloader_source: -> { GraphQL::Current.dataloader_source_class }
      }
    ]
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    config.active_job.queue_adapter = :sidekiq
    config.eager_load_paths << Rails.root.join('lib')

    # Must be set here (not in config/initializers) — ActiveRecord::Railtie
    # reads config.active_record.encryption during its own initializer, which
    # runs before config/initializers/*.rb files are loaded. Values come from
    # config/application.yml (figaro), not config/credentials.yml.enc.
    config.active_record.encryption.primary_key = ENV.fetch('AR_ENCRYPTION_PRIMARY_KEY')
    config.active_record.encryption.deterministic_key = ENV.fetch('AR_ENCRYPTION_DETERMINISTIC_KEY')
    config.active_record.encryption.key_derivation_salt = ENV.fetch('AR_ENCRYPTION_KEY_DERIVATION_SALT')

    # Sidekiq::Web needs session/cookie middleware even though this is an
    # api_only app (which strips them by default).
    config.session_store :cookie_store, key: '_qa_agent_backend_session'
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use config.session_store, config.session_options

    config.generators do |g|
      g.test_framework :rspec,
                       fixtures: true,
                       view_specs: false,
                       helper_specs: false,
                       routing_specs: false,
                       request_specs: true
      g.fixture_replacement :factory_bot, dir: 'spec/factories'
    end
  end
end

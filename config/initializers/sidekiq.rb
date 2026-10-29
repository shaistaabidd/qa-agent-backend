Sidekiq.configure_server { |config| config.redis = Rails.configuration.x.redis }
Sidekiq.configure_client { |config| config.redis = Rails.configuration.x.redis }

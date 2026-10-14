# Heroku's Redis Cloud add-on provides REDISCLOUD_URL; locally (and with other
# Redis providers) it's REDIS_URL.
redis_url = ENV['REDISCLOUD_URL'].presence || ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end

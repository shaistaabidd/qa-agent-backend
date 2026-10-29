# Only the configured frontend origins may call the API. Auth travels in the
# Authorization header, never cookies, so credentials stay off.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*Rails.configuration.x.cors_allowed_origins)

    resource "/graphql",
             headers: %w[Authorization Content-Type Accept Apollo-Require-Preflight],
             methods: %i[post options],
             credentials: false,
             max_age: 2.hours.to_i
  end
end

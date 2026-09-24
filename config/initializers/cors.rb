Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch('FRONTEND_ORIGINS', 'http://localhost:3000').split(',')
    resource '/graphql', headers: :any, methods: %i[post options]
  end
end

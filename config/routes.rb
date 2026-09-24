require 'sidekiq/web'

Rails.application.routes.draw do
  post '/graphql', to: 'graphql#execute'

  # Auth is handled entirely via GraphQL mutations (LoginUser/RegisterUser);
  # Devise is only used for its model concern (password hashing, etc.).
  devise_for :users, skip: :all

  mount GraphiQL::Rails::Engine, at: '/graphiql', graphql_path: '/graphql' if Rails.env.development?

  mount Sidekiq::Web => '/sidekiq' unless Rails.env.test?
end

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  post "/graphql", to: "graphql#execute"

  # Sign in with Google: the browser's two stops on the API (see Auth::GoogleSignIn).
  get "/auth/google", to: "google_sign_ins#new", as: :google_sign_in
  get "/auth/google/callback", to: "google_sign_ins#callback", as: :google_sign_in_callback

  # Feature-flag dashboard, Basic Auth-protected when credentials are set - see config/initializers/flipper_ui.rb.
  mount FlipperUi.app, at: "/flipper"

  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?
end

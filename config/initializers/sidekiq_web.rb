require "sidekiq/web"
require "rack/session/cookie"

# The Sidekiq dashboard (mounted at /sidekiq in config/routes.rb) shows job arguments and can retry or
# delete jobs, so it sits behind the same HTTP Basic Auth as /flipper (FLIPPER_UI_USERNAME and
# FLIPPER_UI_PASSWORD). Production does not mount it until they are set (FlipperUi.exposed?); elsewhere,
# leaving them unset runs it without auth.
module SidekiqUi
  # Basic Auth that reads the credentials per request and lets everyone in while none are configured.
  class OptionalBasicAuth
    def initialize(app)
      @app = app
    end

    def call(env)
      return @app.call(env) unless FlipperUi::USERNAME && FlipperUi::PASSWORD

      Rack::Auth::Basic.new(@app, "Sidekiq") do |username, password|
        # `&`, not `&&`: always compare both, so timing doesn't reveal which one was wrong.
        ActiveSupport::SecurityUtils.secure_compare(username, FlipperUi::USERNAME) &
          ActiveSupport::SecurityUtils.secure_compare(password, FlipperUi::PASSWORD)
      end.call(env)
    end
  end

  def self.app
    Rack::Builder.app do
      use OptionalBasicAuth
      # The dashboard's forms are CSRF-protected with a token kept in a session, and this API-only app
      # has no session middleware. This cookie session is local to /sidekiq.
      use Rack::Session::Cookie, secret: Rails.application.secret_key_base, same_site: :lax,
                                 secure: Rails.env.production?
      run Sidekiq::Web
    end
  end
end

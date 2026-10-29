# Wraps Flipper::UI (mounted at /flipper in config/routes.rb) in HTTP Basic
# Auth. Anyone who reaches the dashboard can change every flag, so production
# does not mount it (or the Sidekiq dashboard, which shares these credentials)
# until both are set; elsewhere, leaving them unset runs it without auth.
require "rack/session/cookie"
require "flipper/ui/decorators/feature"

# Flags are stored in our own Redis, so hide the Flipper Cloud upsell and the
# Settings tab (cloud migration plus export/import, where an import overwrites
# every flag). The tab is only hidden, not blocked - /flipper/settings still
# opens for anyone who can reach the dashboard, so keep the dashboard behind Basic Auth.
Flipper::UI.configure do |config|
  config.cloud_recommendation = false
  config.nav_items = [{ title: "Features", href: "features" }]
end

module FlipperUi
  # The "Add a group" list leaves out roles a flag never applies to
  # (FeatureFlag::NEVER_FOR_ROLES), e.g. no `super_admins` for sign_up_enabled.
  module EligibleGroups
    def disabled_groups
      super.select do |group|
        role = FeatureFlag.role_for_group(group.name)
        role.nil? || FeatureFlag.eligible_role?(key, role)
      end
    end
  end
  Flipper::UI::Decorators::Feature.prepend(EligibleGroups)

  # FeatureFlag::EligibleTargetsAdapter refuses an ineligible group or user;
  # show its message on the form instead of an error page.
  class IneligibleTargetMessage
    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(env)
    rescue FeatureFlag::IneligibleTarget => e
      location = "#{env["SCRIPT_NAME"]}#{env["PATH_INFO"]}?error=#{CGI.escape(e.message)}"
      [302, { "location" => location }, []]
    end
  end

  USERNAME = ENV["FLIPPER_UI_USERNAME"].presence
  PASSWORD = ENV["FLIPPER_UI_PASSWORD"].presence

  # Whether the admin dashboards are routed at all: always outside production, and in production only once
  # both credentials exist. An existing deploy without them boots with the dashboards switched off.
  def self.exposed?
    !Rails.env.production? || (USERNAME.present? && PASSWORD.present?)
  end

  def self.app
    Flipper::UI.app do |builder|
      if USERNAME && PASSWORD
        builder.use Rack::Auth::Basic do |username, password|
          # `&`, not `&&`: always compare both, so timing doesn't reveal which one was wrong.
          ActiveSupport::SecurityUtils.secure_compare(username, USERNAME) &
            ActiveSupport::SecurityUtils.secure_compare(password, PASSWORD)
        end
      end

      # The dashboard's forms are CSRF-protected with a token kept in a session,
      # and this API-only app has no session middleware, so every button click
      # would come back "Forbidden". This cookie session is local to /flipper.
      builder.use Rack::Session::Cookie, secret: Rails.application.secret_key_base, same_site: :lax,
                                         secure: Rails.env.production?
      builder.use IneligibleTargetMessage
    end
  end
end

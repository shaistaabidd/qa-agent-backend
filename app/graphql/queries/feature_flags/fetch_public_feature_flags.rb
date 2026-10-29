module Queries
  module FeatureFlags
    class FetchPublicFeatureFlags < BaseQuery
      description <<~DESC.squish
        For signed-out pages: whether sign-up is open and whether login and sign-up ask for a code, for the
        role public sign-up creates (the server picks it; super admins can never sign up). Every other flag
        needs sign-in (`User.featureFlags`, `fetchFeatureFlags`).
      DESC

      allow_unauthenticated!

      type Types::PublicFeatureFlagsType, null: false

      def resolve
        FeatureFlag.values_for(FeatureFlag.visitor).slice(*FeatureFlag::PUBLIC_NAMES)
      end
    end
  end
end

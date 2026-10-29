module Queries
  module FeatureFlags
    class FetchFeatureFlags < BaseQuery
      description <<~DESC.squish
        Signed in only: every feature flag for the signed-in user, or with `role` for that role (e.g. whether
        users of a role can be invited or impersonated). The same values come on `User.featureFlags`.
        Signed-out pages use `fetchPublicFeatureFlags`.
      DESC

      type Types::FeatureFlagsType, null: false

      argument :role, Types::UserRoleEnum, required: false, description: "Evaluate the flags for this role"

      def resolve(role: nil)
        FeatureFlag.values_for(role ? FeatureFlag.visitor(role:) : current_user)
      end
    end
  end
end

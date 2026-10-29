module Types
  class PublicFeatureFlagsType < BaseObject
    description "The feature flags a signed-out visitor may read, for the role public sign-up creates"

    FeatureFlag::PUBLIC_NAMES.each { field it, Boolean, null: false, description: FeatureFlagsType::DESCRIPTIONS.fetch(it) }
  end
end

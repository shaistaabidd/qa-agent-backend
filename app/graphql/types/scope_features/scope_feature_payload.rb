module Types
  module ScopeFeatures
    class ScopeFeaturePayload < Types::BaseObject
      field :scope_feature, Types::ScopeFeatures::ScopeFeatureType, null: false
    end
  end
end

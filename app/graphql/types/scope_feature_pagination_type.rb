module Types
  class ScopeFeaturePaginationType < BasePaginationType
    description "One page of scope features"

    field :all_data, [ScopeFeatureType], null: false, method: :records, description: "Scope features on this page"
  end
end

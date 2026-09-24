module Types
  module ScopeFeatures
    class ScopeFeaturesPagination < Types::Shared::CorePaginatedType
      field :all_data, [Types::ScopeFeatures::ScopeFeatureType], null: false
    end
  end
end

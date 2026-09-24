module Types
  module Dashboard
    class CoverageType < Types::BaseObject
      field :total_scope_features, Integer, null: false
      field :approved_scope_features, Integer, null: false
      field :tested_scope_features, Integer, null: false
      field :coverage_percentage, Float, null: false
    end
  end
end

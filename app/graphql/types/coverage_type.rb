module Types
  class CoverageType < BaseObject
    description "How much of a project's approved scope has been run"

    field :total_scope_features, Integer, null: false, description: "All scope features"
    field :approved_scope_features, Integer, null: false, description: "Approved scope features"
    field :tested_scope_features, Integer, null: false, description: "Approved scope features with at least one run"
    field :coverage_percentage, Float, null: false, description: "Tested as a percentage of approved"
  end
end

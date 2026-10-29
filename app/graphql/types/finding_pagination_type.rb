module Types
  class FindingPaginationType < BasePaginationType
    description "One page of findings"

    field :all_data, [FindingType], null: false, method: :records, description: "Findings on this page"
  end
end

module Types
  class RunPaginationType < BasePaginationType
    description "One page of runs"

    field :all_data, [RunType], null: false, method: :records, description: "Runs on this page"
  end
end

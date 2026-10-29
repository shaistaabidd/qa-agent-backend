module Types
  class ProjectPaginationType < BasePaginationType
    description "One page of projects"

    field :all_data, [ProjectType], null: false, method: :records, description: "Projects on this page"
  end
end

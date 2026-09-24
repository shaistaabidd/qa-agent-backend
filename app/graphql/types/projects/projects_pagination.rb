module Types
  module Projects
    class ProjectsPagination < Types::Shared::CorePaginatedType
      field :all_data, [Types::Projects::ProjectType], null: false
    end
  end
end

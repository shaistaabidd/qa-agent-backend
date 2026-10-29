module Queries
  module ScopeFeatures
    class AllScopeFeatures < BaseQuery
      include Paginatable
      include ProjectAccess

      description "A project's scope features, newest first"

      type Types::ScopeFeaturePaginationType, null: false

      argument :project_id, ID, description: "Project whose features to list"
      argument :filter, Types::PaginatedFilterInput, required: false, description: "Paging"

      def resolve(project_id:, filter: nil)
        project = find_project(project_id)
        paginate_with_filter(project.scope_features.order(created_at: :desc, id: :desc), filter.to_h)
      end
    end
  end
end

module Queries
  module Projects
    class AllProjects < BaseQuery
      include Paginatable

      description "Projects the signed-in user belongs to (every project for a super admin), newest first"

      type Types::ProjectPaginationType, null: false

      argument :filter, Types::PaginatedFilterInput, required: false, description: "Paging"

      def resolve(filter: nil)
        authorize! Project, to: :index?

        projects = authorized_scope(Project.all).includes(:integrations, :repo_connection)
        paginate_with_filter(projects.order(created_at: :desc, id: :desc), filter.to_h)
      end
    end
  end
end

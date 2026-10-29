module Queries
  module Projects
    class AllProjects < BaseQuery
      include Paginatable

      description "Projects the signed-in user belongs to (every project for a super admin), newest first"

      type Types::ProjectPaginationType, null: false

      argument :filter, Types::PaginatedFilterInput, required: false, description: "Paging"

      extras [:lookahead]

      # Associations are only loaded when the query asks for what needs them.
      def resolve(lookahead:, filter: nil)
        authorize! Project, to: :index?

        fields = lookahead.selection(:all_data)
        projects = authorized_scope(Project.all)
        projects = projects.includes(:integrations) if fields.selects?(:github_installed)
        projects = projects.includes(:repo_connection) if fields.selects?(:repo_full_name)
        paginate_with_filter(projects.order(created_at: :desc, id: :desc), filter.to_h)
      end
    end
  end
end

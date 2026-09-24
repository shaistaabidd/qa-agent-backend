module Queries
  module Projects
    class MyProjects < Queries::BaseQuery
      include AuthenticableApiUser
      include Pagination

      argument :page, Integer, required: false, default_value: 1
      argument :per_page, Integer, required: false, default_value: 20

      type Types::Projects::ProjectsPagination, null: false

      def resolve(**params)
        authenticate_user!

        projects = current_user.projects.order(created_at: :desc)
        pagination_response(paginate(projects, page: params[:page], per_page: params[:per_page]))
      rescue GraphQL::ExecutionError
        raise
      rescue StandardError => e
        execution_error(message: e.message)
      end
    end
  end
end

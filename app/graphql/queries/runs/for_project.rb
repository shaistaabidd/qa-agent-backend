module Queries
  module Runs
    class ForProject < Queries::BaseQuery
      include AuthenticableApiUser
      include PermissionHandler
      include Pagination

      argument :project_id, ID, required: true
      argument :status, Types::Enums::RunStatusEnum, required: false
      argument :page, Integer, required: false, default_value: 1
      argument :per_page, Integer, required: false, default_value: 20

      type Types::Runs::RunsPagination, null: false

      def resolve(**params)
        authenticate_user!
        project = Project.find(params[:project_id])
        authenticate_project_access!(project)

        runs = filtered_runs(project, params[:status])
        pagination_response(paginate(runs, page: params[:page], per_page: params[:per_page]))
      rescue GraphQL::ExecutionError
        raise
      rescue ActiveRecord::RecordNotFound
        execution_error(message: 'Project not found', code: 404)
      rescue StandardError => e
        execution_error(message: e.message)
      end

      private

      def filtered_runs(project, status)
        runs = project.runs.order(created_at: :desc)
        status ? runs.where(status: status) : runs
      end
    end
  end
end

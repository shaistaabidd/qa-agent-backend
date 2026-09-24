module Queries
  module Runs
    class FetchRun < Queries::BaseQuery
      include AuthenticableApiUser
      include PermissionHandler

      argument :id, ID, required: true

      type Types::Runs::RunType, null: false

      def resolve(**params)
        authenticate_user!
        run = Run.find(params[:id])
        authenticate_project_access!(run.project)
        run
      rescue GraphQL::ExecutionError
        raise
      rescue ActiveRecord::RecordNotFound
        execution_error(message: 'Run not found', code: 404)
      rescue StandardError => e
        execution_error(message: e.message)
      end
    end
  end
end

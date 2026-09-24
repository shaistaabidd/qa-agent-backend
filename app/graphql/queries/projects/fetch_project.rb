module Queries
  module Projects
    class FetchProject < Queries::BaseQuery
      include AuthenticableApiUser
      include PermissionHandler

      argument :id, ID, required: true

      type Types::Projects::ProjectType, null: false

      def resolve(**params)
        authenticate_user!
        project = Project.find(params[:id])
        authenticate_project_access!(project)
        project
      rescue GraphQL::ExecutionError
        raise
      rescue ActiveRecord::RecordNotFound
        execution_error(message: 'Project not found', code: 404)
      rescue StandardError => e
        execution_error(message: e.message)
      end
    end
  end
end

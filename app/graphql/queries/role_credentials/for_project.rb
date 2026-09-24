module Queries
  module RoleCredentials
    class ForProject < Queries::BaseQuery
      include AuthenticableApiUser
      include PermissionHandler

      argument :project_id, ID, required: true

      type [Types::RoleCredentials::RoleCredentialType], null: false

      def resolve(**params)
        authenticate_user!
        project = Project.find(params[:project_id])
        authenticate_project_access!(project)

        project.role_credentials.order(:role_name)
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

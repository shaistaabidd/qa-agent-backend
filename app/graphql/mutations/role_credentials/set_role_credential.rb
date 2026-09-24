module Mutations
  module RoleCredentials
    class SetRoleCredential < BaseMutation
      include AuthenticableApiUser
      include PermissionHandler

      argument :project_id, ID, required: true
      argument :role_name, String, required: true
      argument :credential_value, String, required: true

      type Types::RoleCredentials::RoleCredentialPayload

      def resolve(**params)
        authenticate_user!
        project = Project.find(params[:project_id])
        authenticate_project_admin!(project)

        result = ::RoleCredentials::CreateOrUpdate.call(
          project: project, role_name: params[:role_name], credential_value: params[:credential_value]
        )

        result.success? ? result : execution_error(message: result.error)
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

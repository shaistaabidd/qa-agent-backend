module Mutations
  module Integrations
    class ConnectGithub < BaseMutation
      include AuthenticableApiUser
      include PermissionHandler

      argument :project_id, ID, required: true
      argument :installation_id, String, required: true
      argument :repo_full_name, String, required: true

      type Types::Projects::ProjectPayload

      def resolve(**params)
        authenticate_user!
        project = Project.find(params[:project_id])
        authenticate_project_admin!(project)

        result = ::Integrations::ConnectGithub.call(
          project: project,
          installation_id: params[:installation_id],
          repo_full_name: params[:repo_full_name]
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

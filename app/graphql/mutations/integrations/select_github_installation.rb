module Mutations
  module Integrations
    class SelectGithubInstallation < BaseMutation
      include AuthenticableApiUser
      include PermissionHandler

      argument :choice_token, String, required: true
      argument :installation_id, String, required: true

      type Types::Projects::ProjectPayload

      def resolve(**params)
        authenticate_user!
        payload = GitHubInstallState.verify_choice(params[:choice_token])
        authenticate_project_admin!(Project.find_by(id: payload&.dig('project_id'))) if payload

        result = ::Integrations::SelectGithubInstallation.call(user: current_user, **params)

        result.success? ? result : execution_error(message: result.error)
      rescue GraphQL::ExecutionError
        raise
      rescue StandardError => e
        execution_error(message: e.message)
      end
    end
  end
end

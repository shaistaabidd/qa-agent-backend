module Mutations
  module Integrations
    class AuthorizeGithubUser < BaseMutation
      include AuthenticableApiUser
      include PermissionHandler

      argument :state, String, required: true
      argument :code, String, required: true

      type Types::Integrations::GithubAuthorizationPayload

      def resolve(**params)
        authenticate_user!
        payload = GitHubInstallState.verify(params[:state])
        authenticate_project_admin!(Project.find_by(id: payload&.dig('project_id'))) if payload

        result = ::Integrations::AuthorizeGithubUser.call(user: current_user, **params)

        result.success? ? result : execution_error(message: result.error)
      rescue GraphQL::ExecutionError
        raise
      rescue StandardError => e
        execution_error(message: e.message)
      end
    end
  end
end

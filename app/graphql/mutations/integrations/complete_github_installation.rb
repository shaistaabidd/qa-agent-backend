module Mutations
  module Integrations
    class CompleteGithubInstallation < BaseMutation
      include ProjectAccess

      description "Finishes the GitHub App install redirect and stores the installation on the project"

      rate_limit to: 20, within: 10.minutes, by: ->(_) { current_user.id }

      argument :state, String, description: "The signed state GitHub echoed back"
      argument :installation_id, String, description: "GitHub's installation id"
      argument :code, String, description: "The OAuth code GitHub sent with the redirect"

      field :project, Types::ProjectType, null: false, description: "The project"

      def resolve(state:, installation_id:, code:)
        payload = GitHubInstallState.verify(state)
        find_project(payload["project_id"], to: :manage?) if payload

        result = ::Integrations::LinkGithubInstallation.call(user: current_user, state:, installation_id:, code:)
        { project: value_or_raise!(result) }
      end
    end
  end
end

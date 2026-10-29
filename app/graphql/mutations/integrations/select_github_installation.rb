module Mutations
  module Integrations
    class SelectGithubInstallation < BaseMutation
      include ProjectAccess

      description "Links the installation the user picked after \"sign in with GitHub\""

      rate_limit to: 20, within: 10.minutes, by: ->(_) { current_user.id }

      argument :choice_token, String, description: "From authorizeGithubUser"
      argument :installation_id, String, description: "The chosen installation"

      field :project, Types::ProjectType, null: false, description: "The project"

      def resolve(choice_token:, installation_id:)
        payload = GitHubInstallState.verify_choice(choice_token)
        find_project(payload["project_id"], to: :manage?) if payload

        result = ::Integrations::SelectGithubInstallation.call(user: current_user, choice_token:, installation_id:)
        { project: value_or_raise!(result) }
      end
    end
  end
end

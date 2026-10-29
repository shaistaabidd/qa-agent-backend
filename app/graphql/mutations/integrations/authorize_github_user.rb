module Mutations
  module Integrations
    class AuthorizeGithubUser < BaseMutation
      include ProjectAccess

      description "Finishes \"sign in with GitHub\": lists the existing installations the user can access"

      rate_limit to: 20, within: 10.minutes, by: ->(_) { current_user.id }

      argument :state, String, description: "The signed state GitHub echoed back"
      argument :code, String, description: "The OAuth code GitHub sent with the redirect"

      field :choice_token, String, null: false, description: "Pass back to selectGithubInstallation"
      field :installations, [Types::GithubInstallationType], null: false, description: "Installations to choose from"

      def resolve(state:, code:)
        payload = GitHubInstallState.verify(state)
        find_project(payload["project_id"], to: :manage?) if payload

        authorization = value_or_raise!(::Integrations::AuthorizeGithubUser.call(user: current_user, state:, code:))
        { choice_token: authorization.choice_token, installations: authorization.installations }
      end
    end
  end
end

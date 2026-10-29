module Queries
  module Integrations
    class FetchGithubAuthorizeUrl < BaseQuery
      include ProjectAccess

      description "Project admins: where to send the user to sign in with GitHub and pick an existing installation"

      type String, null: false

      argument :project_id, ID, description: "Project to connect"

      def resolve(project_id:)
        project = find_project(project_id, to: :manage?)
        GitHubUserAuthorization.authorize_url(GitHubInstallState.generate(project:, user: current_user))
      end
    end
  end
end

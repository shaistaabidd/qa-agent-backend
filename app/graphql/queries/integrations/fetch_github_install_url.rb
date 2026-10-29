module Queries
  module Integrations
    class FetchGithubInstallUrl < BaseQuery
      include ProjectAccess

      description "Project admins: where to send the user to install the GitHub App for a project"

      type String, null: false

      argument :project_id, ID, description: "Project to connect"

      def resolve(project_id:)
        project = find_project(project_id, to: :manage?)
        GitHubAppService.install_url(GitHubInstallState.generate(project:, user: current_user))
      end
    end
  end
end

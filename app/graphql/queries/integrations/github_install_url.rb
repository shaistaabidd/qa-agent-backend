module Queries
  module Integrations
    class GithubInstallUrl < Queries::BaseQuery
      include AuthenticableApiUser
      include PermissionHandler

      argument :project_id, ID, required: true

      type String, null: false

      def resolve(**params)
        authenticate_user!
        project = Project.find(params[:project_id])
        authenticate_project_admin!(project)

        GitHubAppService.install_url(GitHubInstallState.generate(project: project, user: current_user))
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

module Queries
  module Integrations
    class GithubRepositories < Queries::BaseQuery
      include AuthenticableApiUser
      include PermissionHandler

      argument :project_id, ID, required: true

      type [String], null: false

      def resolve(**params)
        authenticate_user!
        project = Project.find(params[:project_id])
        authenticate_project_admin!(project)

        integration = project.integrations.github.first
        raise execution_error(message: 'Install the GitHub App first') unless integration

        GitHubAppService.for_installation(integration.external_account_id).repository_names
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

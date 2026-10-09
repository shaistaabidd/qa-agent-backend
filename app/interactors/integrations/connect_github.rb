module Integrations
  # Links one of the installation's repos to the project. The App must
  # already be installed (LinkGithubInstallation).
  class ConnectGithub < BaseInteractor
    delegate :project, to: :context

    def call
      integration = installed_integration
      require_accessible_repo!(integration)

      integration.update!(repo_full_name: context.repo_full_name, connected_at: Time.current)
      project.update!(repo_connection: integration)
      context.project = project
    rescue ActiveRecord::RecordInvalid => e
      context.fail!(error: e.record.errors.full_messages.to_sentence)
    end

    private

    def installed_integration
      project.integrations.github.first || context.fail!(error: 'Install the GitHub App before choosing a repo')
    end

    def require_accessible_repo!(integration)
      repos = GitHubAppService.for_installation(integration.external_account_id).repository_names
      return if repos.include?(context.repo_full_name)

      context.fail!(error: "The GitHub App doesn't have access to #{context.repo_full_name}")
    end
  end
end

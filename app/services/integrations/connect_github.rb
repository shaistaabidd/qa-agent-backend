module Integrations
  # Links one of the installation's repositories to the project. The App must already be
  # installed (LinkGithubInstallation).
  class ConnectGithub < ApplicationService
    def initialize(project:, repo_full_name:)
      @project = project
      @repo_full_name = repo_full_name
    end

    def call
      integration = @project.integrations.github.first
      return failure(:github_not_installed) unless integration
      return failure(:github_repo_inaccessible) unless accessible?(integration)

      connect(integration) ? success(@project) : failure(:validation_failed, record: integration)
    rescue GitHubUserAuthorization::AuthorizationError, Octokit::Error => e
      Rails.logger.warn("[GitHub] connecting repository failed: #{e.class}: #{e.message}")
      failure(:github_failed)
    end

    private

    def accessible?(integration)
      GitHubAppService.for_installation(integration.external_account_id).repository_names.include?(@repo_full_name)
    end

    def connect(integration)
      Project.transaction do
        integration.update(repo_full_name: @repo_full_name, connected_at: Time.current) &&
          @project.update(repo_connection: integration)
      end
    end
  end
end

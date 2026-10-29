module ScopeFeatures
  # Reads the connected repository's routes and controllers and records each as a scope feature.
  # Features seen before are left as they are, so approvals survive a rescan.
  class ScanCodebase < ApplicationService
    def initialize(project:)
      @project = project
    end

    def call
      integration = @project.repo_connection
      return failure(:repo_not_connected) unless integration

      success(persist(extract_features(integration)))
    rescue GitHubUserAuthorization::AuthorizationError, Octokit::Error => e
      Rails.logger.warn("[GitHub] scan failed: #{e.class}: #{e.message}")
      failure(:github_failed)
    end

    private

    def extract_features(integration)
      github = GitHubAppService.for_installation(integration.external_account_id)
      CodebaseAnalyzer.new(github, integration.repo_full_name).extract_features
    end

    def persist(features)
      Array(features).map do |feature|
        @project.scope_features.find_or_create_by!(name: feature[:name]) do |scope_feature|
          scope_feature.route = feature[:route]
          scope_feature.source = feature[:source]
        end
      end
    end
  end
end

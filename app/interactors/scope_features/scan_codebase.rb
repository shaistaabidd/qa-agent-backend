module ScopeFeatures
  class ScanCodebase < BaseInteractor
    delegate :project, to: :context

    def call
      require_repo_connection!
      context.scope_features = persist(extract_features)
    end

    private

    def require_repo_connection!
      return if project.repo_connection

      context.fail!(error: 'Project has no connected GitHub repository')
    end

    def extract_features
      integration = project.repo_connection
      github_service = GitHubAppService.for_installation(integration.external_account_id)
      CodebaseAnalyzer.new(github_service, integration.repo_full_name).extract_features
    end

    def persist(features)
      Array(features).map do |feature|
        project.scope_features.find_or_create_by!(name: feature[:name]) do |scope_feature|
          scope_feature.route = feature[:route]
          scope_feature.source = feature[:source]
        end
      end
    end
  end
end

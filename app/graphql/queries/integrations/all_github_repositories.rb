module Queries
  module Integrations
    class AllGithubRepositories < BaseQuery
      include ProjectAccess

      description "Project admins: the repositories the project's GitHub App installation can see"

      type [String], null: false

      argument :project_id, ID, description: "Project whose installation to read"

      def resolve(project_id:)
        repository_names(find_project(project_id, to: :manage?).integrations.github.first)
      rescue Octokit::Error => e
        Rails.logger.warn("[GitHub] listing repositories failed: #{e.class}: #{e.message}")
        raise GraphqlErrors.build(I18n.t("errors.github_failed"), :github_failed)
      end

      private

      def repository_names(integration)
        raise GraphqlErrors.build(I18n.t("errors.github_not_installed"), :github_not_installed) unless integration

        GitHubAppService.for_installation(integration.external_account_id).repository_names
      end
    end
  end
end

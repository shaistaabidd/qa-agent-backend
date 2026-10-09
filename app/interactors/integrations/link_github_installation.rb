module Integrations
  # Completes the GitHub App install redirect: verifies the signed state and
  # that the user really can access the installation, then stores it on the
  # project. Picking the repo is a separate step (ConnectGithub).
  class LinkGithubInstallation < BaseInteractor
    def call
      project = verified_project
      verify_installation_access!
      context.project = project.attach_github_installation!(context.installation_id)
    rescue GitHubUserAuthorization::AuthorizationError, Octokit::Error => e
      Rails.logger.warn("[GitHub] linking installation failed: #{e.class}: #{e.message}")
      context.fail!(error: e.message)
    rescue ActiveRecord::RecordInvalid => e
      context.fail!(error: e.record.errors.full_messages.to_sentence)
    end

    private

    def verified_project
      payload = GitHubInstallState.verify(context.state)
      context.fail!(error: 'GitHub connection link expired — please connect again') unless payload
      context.fail!(error: 'This GitHub connection was started by a different user') unless
        payload['user_id'] == context.user.id

      Project.find(payload['project_id'])
    end

    def verify_installation_access!
      return if GitHubUserAuthorization.new(context.code).can_access_installation?(context.installation_id)

      context.fail!(error: 'You do not have access to that GitHub installation')
    end
  end
end

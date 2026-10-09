module Integrations
  # "Sign in with GitHub" callback: lists the existing installations of the
  # App this user can access (e.g. one an org owner installed) and signs that
  # list into a choice token, since the OAuth code can't be used twice.
  class AuthorizeGithubUser < BaseInteractor
    def call
      payload = verified_state
      installations = GitHubUserAuthorization.new(context.code).installations

      context.installations = installations
      context.choice_token = GitHubInstallState.generate_choice(
        project_id: payload['project_id'], user_id: context.user.id, installation_ids: installations.pluck(:id)
      )
    rescue GitHubUserAuthorization::AuthorizationError, Octokit::Error => e
      Rails.logger.warn("[GitHub] sign-in failed: #{e.class}: #{e.message}")
      context.fail!(error: e.message)
    end

    private

    def verified_state
      payload = GitHubInstallState.verify(context.state)
      context.fail!(error: 'GitHub sign-in link expired — please try again') unless payload
      context.fail!(error: 'This GitHub sign-in was started by a different user') unless
        payload['user_id'] == context.user.id
      payload
    end
  end
end

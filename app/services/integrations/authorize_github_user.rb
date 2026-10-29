module Integrations
  # "Sign in with GitHub" callback: lists the App installations this user can access (for example
  # one an org owner installed) and signs the list into a choice token, since the OAuth code
  # can't be used twice.
  class AuthorizeGithubUser < ApplicationService
    Result = Data.define(:installations, :choice_token)

    def initialize(user:, state:, code:)
      @user = user
      @state = state
      @code = code
    end

    def call
      payload = GitHubInstallState.verify(@state)
      return failure(:github_link_expired) unless payload
      return failure(:github_wrong_user) unless payload["user_id"] == @user.id

      success(result_for(payload["project_id"]))
    rescue GitHubUserAuthorization::AuthorizationError, Octokit::Error => e
      Rails.logger.warn("[GitHub] sign-in failed: #{e.class}: #{e.message}")
      failure(:github_failed)
    end

    private

    def result_for(project_id)
      installations = GitHubUserAuthorization.new(@code).installations
      choice_token = GitHubInstallState.generate_choice(project_id:, user_id: @user.id,
                                                        installation_ids: installations.pluck(:id))
      Result.new(installations:, choice_token:)
    end
  end
end

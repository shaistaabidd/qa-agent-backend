module Integrations
  # Completes the GitHub App install redirect: checks the signed state and that the user can really
  # access the installation, then stores it on the project. Picking the repo is ConnectGithub.
  class LinkGithubInstallation < ApplicationService
    def initialize(user:, state:, installation_id:, code:)
      @user = user
      @state = state
      @installation_id = installation_id
      @code = code
    end

    def call
      payload = GitHubInstallState.verify(@state)
      rejection = rejection_for(payload)
      return failure(rejection) if rejection

      success(Project.find(payload["project_id"]).attach_github_installation!(@installation_id))
    rescue GitHubUserAuthorization::AuthorizationError, Octokit::Error => e
      Rails.logger.warn("[GitHub] linking installation failed: #{e.class}: #{e.message}")
      failure(:github_failed)
    rescue ActiveRecord::RecordInvalid => e
      failure(:validation_failed, record: e.record)
    end

    private

    def rejection_for(payload)
      return :github_link_expired unless payload
      return :github_wrong_user unless payload["user_id"] == @user.id

      :github_access_denied unless GitHubUserAuthorization.new(@code).can_access_installation?(@installation_id)
    end
  end
end

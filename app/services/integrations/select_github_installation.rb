module Integrations
  # Second half of "Sign in with GitHub": links the installation the user picked, provided GitHub
  # confirmed they can access it.
  class SelectGithubInstallation < ApplicationService
    def initialize(user:, choice_token:, installation_id:)
      @user = user
      @choice_token = choice_token
      @installation_id = installation_id
    end

    def call
      payload = GitHubInstallState.verify_choice(@choice_token)
      return failure(:github_link_expired) unless payload
      return failure(:github_access_denied) unless allowed?(payload)

      success(Project.find(payload["project_id"]).attach_github_installation!(@installation_id))
    rescue ActiveRecord::RecordInvalid => e
      failure(:validation_failed, record: e.record)
    end

    private

    def allowed?(payload)
      payload["user_id"] == @user.id && payload["installation_ids"].include?(@installation_id.to_i)
    end
  end
end

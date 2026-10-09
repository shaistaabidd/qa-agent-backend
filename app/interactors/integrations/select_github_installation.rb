module Integrations
  # Second half of "Sign in with GitHub": links the installation the user
  # picked, provided it's one GitHub confirmed they can access.
  class SelectGithubInstallation < BaseInteractor
    def call
      payload = GitHubInstallState.verify_choice(context.choice_token)
      context.fail!(error: 'GitHub sign-in expired — please sign in again') unless payload
      context.fail!(error: 'You do not have access to that GitHub installation') unless
        payload['user_id'] == context.user.id && payload['installation_ids'].include?(context.installation_id.to_i)

      context.project = Project.find(payload['project_id']).attach_github_installation!(context.installation_id)
    rescue ActiveRecord::RecordInvalid => e
      context.fail!(error: e.record.errors.full_messages.to_sentence)
    end
  end
end

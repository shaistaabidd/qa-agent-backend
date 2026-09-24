module Integrations
  class ConnectGithub < BaseInteractor
    delegate :project, to: :context

    def call
      integration = upsert_integration
      project.update!(repo_connection: integration)
      context.project = project
    rescue ActiveRecord::RecordInvalid => e
      context.fail!(error: e.record.errors.full_messages.to_sentence)
    end

    private

    def upsert_integration
      integration = project.integrations.find_or_initialize_by(integration_type: :github)
      integration.update!(
        external_account_id: context.installation_id,
        repo_full_name: context.repo_full_name,
        scope: 'contents:read',
        connected_at: Time.current
      )
      integration
    end
  end
end

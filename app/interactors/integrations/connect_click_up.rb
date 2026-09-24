module Integrations
  class ConnectClickUp < BaseInteractor
    delegate :project, to: :context

    def call
      integration = project.integrations.find_or_initialize_by(integration_type: :click_up)
      integration.update!(external_account_id: context.list_id, connected_at: Time.current)
      context.project = project
    rescue ActiveRecord::RecordInvalid => e
      context.fail!(error: e.record.errors.full_messages.to_sentence)
    end
  end
end

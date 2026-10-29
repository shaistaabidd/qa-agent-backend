module Integrations
  class ConnectClickUp < ApplicationService
    def initialize(project:, list_id:)
      @project = project
      @list_id = list_id
    end

    def call
      integration = @project.integrations.find_or_initialize_by(integration_type: :click_up)
      integration.assign_attributes(external_account_id: @list_id, connected_at: Time.current)
      return failure(:validation_failed, record: integration) unless integration.save

      success(@project)
    end
  end
end

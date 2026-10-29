# Posts a finding to the project's ClickUp list, once. Rate limits and server errors retry; a
# missing configuration or a rejected request is logged and dropped.
class ClickUpPostJob < ApplicationJob
  queue_as :default

  retry_on ClickUpService::TransientError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveRecord::RecordNotFound

  def perform(finding_id)
    finding = Finding.find(finding_id)
    return if finding.clickup_task_id.present?

    list_id = clickup_list_id(finding)
    return unless list_id

    finding.update!(clickup_task_id: ClickUpService.new.create_task(list_id, finding))
  rescue ClickUpService::ConfigurationError, ClickUpService::PostError => e
    Rails.logger.error("ClickUpPostJob failed for finding #{finding_id}: #{e.message}")
  end

  private

  def clickup_list_id(finding)
    finding.run.project.integrations.find_by(integration_type: :click_up)&.external_account_id
  end
end

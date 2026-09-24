class ClickUpPostJob < ApplicationJob
  queue_as :default

  def perform(finding_id)
    finding = Finding.find(finding_id)
    return if finding.clickup_task_id.present?

    list_id = clickup_list_id(finding)
    return unless list_id

    task_id = ClickUpService.new.create_task(list_id, finding)
    finding.update!(clickup_task_id: task_id)
  rescue ClickUpService::ConfigurationError, ClickUpService::PostError => e
    Rails.logger.error("ClickUpPostJob failed for finding #{finding_id}: #{e.message}")
  end

  private

  def clickup_list_id(finding)
    finding.run.project.integrations.find_by(integration_type: :click_up)&.external_account_id
  end
end

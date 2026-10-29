class RepoScanJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(project_id)
    result = ScopeFeatures::ScanCodebase.call(project: Project.find(project_id))
    Rails.logger.error("RepoScanJob failed for project #{project_id}: #{result.error.message}") if result.failure?
  end
end

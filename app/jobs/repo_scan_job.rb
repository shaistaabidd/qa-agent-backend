class RepoScanJob < ApplicationJob
  queue_as :default

  def perform(project_id)
    project = Project.find(project_id)
    ScopeFeatures::ScanCodebase.call!(project: project)
  end
end

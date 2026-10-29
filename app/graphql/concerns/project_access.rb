# Looks projects up for an operation. A non-member gets "not found", so project ids can't be probed;
# a member who may not do the action gets "forbidden".
module ProjectAccess
  private

  def find_project(id, to: :show?)
    project = authorized_scope(Project.all).find(id)
    authorize!(project, to:)
    project
  end

  # A record that belongs to a project (scope feature, run), found only inside the user's projects.
  def find_in_projects(model, id) = model.where(project_id: authorized_scope(Project.all).select(:id)).find(id)
end

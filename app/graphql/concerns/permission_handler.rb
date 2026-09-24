module PermissionHandler
  extend ActiveSupport::Concern

  private

  # Any member (admin or member) of the project may read/act within it.
  def authenticate_project_access!(project)
    raise forbidden_error unless project && membership_for(project)
  end

  # Only the project admin may perform destructive/config actions
  # (connecting GitHub, storing credentials, approving scope, etc.)
  def authenticate_project_admin!(project)
    raise forbidden_error unless membership_for(project)&.admin?
  end

  def membership_for(project)
    return nil unless current_user && project

    @membership_cache ||= {}
    @membership_cache[project.id] ||= current_user.memberships.find_by(project_id: project.id)
  end

  def forbidden_error
    GraphQL::ExecutionError.new('Access Denied!', options: { status: :forbidden, code: 403 })
  end
end

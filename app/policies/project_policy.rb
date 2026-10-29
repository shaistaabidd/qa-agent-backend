# Who may use a project. Every other QA record (scope features, runs, findings, credentials,
# integrations) belongs to a project, so operations authorize against its project and read through
# `project.<association>`: project members read, project admins change, super admins do both.
class ProjectPolicy < ApplicationPolicy
  relation_scope do |relation|
    super_admin? ? relation : relation.where(id: user.memberships.select(:project_id))
  end

  def index? = true
  def create? = true
  def show? = super_admin? || member?

  # Connecting GitHub or ClickUp, storing credentials, approving scope, scanning and dispatching runs.
  def manage? = super_admin? || project_admin?

  private

  def role = @role ||= user.memberships.find_by(project_id: record.id)&.role

  def member? = role.present?
  def project_admin? = role == "admin"
end

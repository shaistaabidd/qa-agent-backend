# Records only super admins may list or read (admin logs). A model's policy
# inherits from this to get the same rules and scope.
class SuperAdminOnlyPolicy < ApplicationPolicy
  relation_scope do |relation|
    super_admin? ? relation : relation.none
  end

  def index? = super_admin?
  def show? = super_admin?
end

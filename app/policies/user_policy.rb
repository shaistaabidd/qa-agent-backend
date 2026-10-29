class UserPolicy < ApplicationPolicy
  relation_scope do |relation|
    super_admin? ? relation : relation.where(id: user.id)
  end

  def index? = super_admin?
  def show? = super_admin? || own_account?
  def update? = super_admin? || own_account?

  # Credentials are only changed by their owner, never through impersonation.
  def change_credentials? = own_account? && !impersonating?

  # Admin actions never target the acting admin, so nobody can lock themselves out.
  def manage? = super_admin? && !own_account?
  # record is the person being invited (a new User with the requested role):
  # invitations_enabled decides, per role, who may be invited.
  def invite? = super_admin? && FeatureFlag.enabled?(:invitations_enabled, record)
  def manage_invitation? = manage? && record.invitation_pending?
  # impersonation_enabled is checked against the user being impersonated; it
  # never applies to super admins (FeatureFlag::NEVER_FOR_ROLES).
  def impersonate? = manage? && record.can_sign_in? && FeatureFlag.enabled?(:impersonation_enabled, record)

  alias_rule :archive?, :update_access?, to: :manage?
  alias_rule :resend_invitation?, :destroy_invitation?, to: :manage_invitation?

  private

  def own_account? = record.id == user.id
end

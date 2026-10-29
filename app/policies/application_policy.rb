class ApplicationPolicy < ActionPolicy::Base
  authorize :user
  authorize :session, optional: true

  private

  def super_admin? = user.super_admin?
  def impersonating? = session&.impersonated? || false
end

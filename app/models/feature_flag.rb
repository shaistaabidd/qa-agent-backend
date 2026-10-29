# The feature flags this app checks, stored in Flipper. Each flag can be
# switched on for everyone, for a role (a Flipper group per User.role, e.g.
# `users`, `super_admins`), or for one user; a flag is off for anyone it
# hasn't been switched on for. Always check a flag against the person it is
# about: the role signing up, the user signing in or changing email, the role
# being invited, the user being impersonated.
module FeatureFlag
  NAMES = %i[
    sign_up_enabled otp_enabled email_change_otp_enabled invitations_enabled impersonation_enabled
    google_sign_in_enabled sms_enabled
  ].freeze
  # The only flags a signed-out visitor may read: whether they can sign up,
  # whether login and sign-up ask for a code, and whether to offer Google.
  PUBLIC_NAMES = %i[sign_up_enabled otp_enabled google_sign_in_enabled].freeze

  # Roles a flag never applies to, whatever the dashboard says (even fully on):
  # nobody signs up as, is invited as, or is impersonated as a super admin.
  # The dashboard also can't switch these on for such a role's group or users
  # (see EligibleTargetsAdapter); this check still covers "fully on".
  NEVER_FOR_ROLES = {
    sign_up_enabled: %w[super_admin],
    invitations_enabled: %w[super_admin],
    impersonation_enabled: %w[super_admin]
  }.freeze

  # Stands in for a signed-out caller, who has no user record but will act in
  # a known role (public sign-up always creates User::SIGN_UP_ROLE).
  Visitor = Data.define(:role) do
    def flipper_id = "Role;#{role}"
  end

  # Raised when anything tries to switch a flag on for a role it never applies to.
  class IneligibleTarget < StandardError; end

  module_function

  def enabled?(name, actor)
    raise ArgumentError, "Unknown feature flag: #{name}" unless NAMES.include?(name)
    return false unless eligible_role?(name, actor.role)

    Flipper.enabled?(name, actor)
  end

  def eligible_role?(name, role) = NEVER_FOR_ROLES.fetch(name.to_sym, []).exclude?(role.to_s)

  # The role behind a Flipper group name (`super_admins` -> "super_admin"), nil for other groups.
  def role_for_group(group_name) = User.roles.each_key.find { role_group(it).to_s == group_name.to_s }

  def values_for(actor) = NAMES.index_with { enabled?(it, actor) }

  def visitor(role: User::SIGN_UP_ROLE) = Visitor.new(role: role.to_s)

  def role_group(role) = role.to_s.pluralize.to_sym

  # Groups live in memory, so every process registers them once at boot.
  def register_role_groups
    User.roles.each_key do |role|
      Flipper.register(role_group(role)) { |actor| actor.respond_to?(:role) && actor.role.to_s == role }
    end
  end

  # Makes every flag visible (still off) in the dashboard. Writes to Redis, so it
  # runs from `bin/rails feature_flags:register`, never at boot.
  def register_all = NAMES.each { Flipper.add(it) }
end

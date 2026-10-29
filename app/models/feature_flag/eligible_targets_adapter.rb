module FeatureFlag
  # Wraps Flipper's storage so no write (dashboard, console, code) can switch a
  # flag on for a role it never applies to (FeatureFlag::NEVER_FOR_ROLES): not
  # that role's group, and not a user (actor `User;<id>`) who has that role.
  class EligibleTargetsAdapter < Flipper::Adapters::Wrapper
    def wrap(method, *, **kwargs, &)
      refuse_ineligible_target(*) if method == :enable
      super
    end

    private

    def refuse_ineligible_target(feature, gate, thing)
      role = case gate.key
             when :groups then FeatureFlag.role_for_group(thing.value)
             when :actors then role_of_actor(thing.value)
             end
      return if role.nil? || FeatureFlag.eligible_role?(feature.key, role)

      raise IneligibleTarget, "#{feature.key} can never be switched on for #{role.humanize.downcase.pluralize}."
    end

    def role_of_actor(flipper_id)
      type, id = flipper_id.split(";", 2)
      User.where(id:).pick(:role) if type == User.name
    end
  end
end

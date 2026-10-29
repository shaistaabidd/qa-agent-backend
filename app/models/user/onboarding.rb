class User
  # Where a user stands in onboarding. Steps (User::ONBOARDING_STEPS) run in
  # order; a step is complete when every field it needs is present, and the
  # first incomplete one is where the user continues. Super admins don't
  # onboard: they are created by an admin or a seed, not by signing up.
  class Onboarding
    Step = Data.define(:name, :position, :missing_fields) do
      def completed? = missing_fields.empty?
    end

    def initialize(user)
      @user = user
    end

    def required? = !@user.super_admin?

    # The phone step only exists while text messages are on for this user (sms_enabled);
    # without SMS there is nothing to collect a number for. Positions stay contiguous.
    def steps
      @steps ||= applicable_steps.each.with_index(1).map do |(name, fields), position|
        missing_fields = fields.select { @user.public_send(it).blank? }
        Step.new(name:, position:, missing_fields:)
      end
    end

    # The step to show next, or nil when nothing is left (or onboarding doesn't apply).
    def current_step
      return unless required?

      steps.find { !it.completed? }
    end

    def completed? = current_step.nil?

    private

    def applicable_steps
      return ONBOARDING_STEPS if FeatureFlag.enabled?(:sms_enabled, @user)

      ONBOARDING_STEPS.except(:step2)
    end
  end
end

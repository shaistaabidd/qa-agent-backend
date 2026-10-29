module Types
  class OnboardingType < BaseObject
    description "Where the user stands in onboarding; it comes with the user, so no separate query is needed"

    field :required, Boolean, null: false, method: :required?,
                              description: "False for super admins, who don't onboard"
    field :completed, Boolean, null: false, method: :completed?,
                               description: "Every step is complete (always true when not required)"
    field :current_step, OnboardingStepEnum,
          description: "The first incomplete step, where the user continues; null when onboarding is done"
    field :steps, [OnboardingStepType], null: false, description: "Every step in order, with its completion"

    def current_step = object.current_step&.name
  end
end

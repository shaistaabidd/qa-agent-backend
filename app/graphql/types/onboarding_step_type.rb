module Types
  class OnboardingStepType < BaseObject
    description "One onboarding step and whether its details are filled in"

    field :step, OnboardingStepEnum, null: false, method: :name, description: "Which step"
    field :position, Integer, null: false, description: "1 for the first step, 2 for the second, ..."
    field :completed, Boolean, null: false, method: :completed?, description: "Every field the step needs is present"
    field :missing_fields, [String], null: false,
                                     description: "Fields still empty, as named in updateUser (e.g. firstName, phone)"

    def missing_fields = object.missing_fields.map { it.to_s.camelize(:lower) }
  end
end

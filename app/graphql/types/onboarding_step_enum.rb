module Types
  class OnboardingStepEnum < BaseEnum
    DESCRIPTIONS = {
      "step1" => "Step 1: first and last name",
      "step2" => "Step 2: phone number"
    }.freeze

    description "An onboarding step, in the order users complete them"

    User::ONBOARDING_STEPS.each_key { value it.to_s, DESCRIPTIONS.fetch(it.to_s), value: it }
  end
end

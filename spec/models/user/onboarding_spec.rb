require "rails_helper"

RSpec.describe User::Onboarding do
  def onboarding(**attributes) = build(:user, first_name: nil, last_name: nil, phone: nil, **attributes).onboarding

  it "starts at the first step when nothing is filled in" do
    expect(onboarding).to have_attributes(current_step: have_attributes(name: :step1), completed?: false)
  end

  it "moves to step 2 once the names are present" do
    result = onboarding(first_name: "Ada", last_name: "Lovelace")

    expect(result.steps.map { [it.name, it.completed?] }).to eq([[:step1, true], [:step2, false]])
    expect(result.current_step.name).to eq(:step2)
  end

  it "goes back to the first incomplete step, in order, even when a later one is done" do
    result = onboarding(first_name: "Ada", phone: "+12015550123")

    expect(result.current_step).to have_attributes(name: :step1, missing_fields: [:last_name])
  end

  it "is complete when every step is" do
    expect(onboarding(first_name: "Ada", last_name: "Lovelace", phone: "+12015550123"))
      .to have_attributes(current_step: nil, completed?: true)
  end

  it "drops the phone step while text messages are off for the user" do
    with_feature_disabled(:sms_enabled) do
      result = onboarding(first_name: "Ada", last_name: "Lovelace")

      expect(result.steps.map(&:name)).to eq([:step1])
      expect(result).to have_attributes(current_step: nil, completed?: true)
    end
  end

  it "does not apply to super admins" do
    expect(onboarding(role: :super_admin)).to have_attributes(required?: false, completed?: true, current_step: nil)
  end
end

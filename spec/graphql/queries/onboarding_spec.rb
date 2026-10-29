require "rails_helper"

RSpec.describe "Onboarding", type: :graphql do
  let(:onboarding_fields) do
    "onboarding { required completed currentStep steps { step position completed missingFields } }"
  end
  let(:user) { create(:user, first_name: nil, last_name: nil) }

  def onboarding_for(person)
    execute_graphql("{ fetchUser { #{onboarding_fields} } }", as: person).dig("data", "fetchUser", "onboarding")
  end

  def update(attributes, as:)
    execute_graphql(<<~GQL, variables: { attributes: }, as:)
      mutation($attributes: UserAttributesInput!) {
        updateUser(input: { userAttributes: $attributes }) { user { phone #{onboarding_fields} } }
      }
    GQL
  end

  it "comes with fetchUser: each step, the next one, and overall completion" do
    expect(onboarding_for(user)).to eq(
      "required" => true, "completed" => false, "currentStep" => "step1",
      "steps" => [
        { "step" => "step1", "position" => 1, "completed" => false, "missingFields" => %w[firstName lastName] },
        { "step" => "step2", "position" => 2, "completed" => false, "missingFields" => ["phone"] }
      ]
    )
  end

  it "moves to step 2 once step 1 is saved, and completes after step 2" do
    step_one = update({ firstName: "Ada", lastName: "Lovelace" }, as: user).dig("data", "updateUser", "user",
                                                                                "onboarding")
    step_two = update({ phone: "+1 201 555 0123" }, as: user).dig("data", "updateUser", "user")

    expect(step_one).to include("completed" => false, "currentStep" => "step2")
    expect(step_one["steps"].pluck("completed")).to eq([true, false])
    expect(step_two).to include("phone" => "+12015550123")
    expect(step_two["onboarding"]).to include("completed" => true, "currentStep" => nil)
  end

  it "sends the user back to step 1 when step 2 is done but step 1 is not" do
    user.update!(phone: "+12015550123", first_name: "Ada")

    expect(onboarding_for(user)).to include("currentStep" => "step1", "completed" => false)
  end

  it "rejects an invalid phone number with a message and keeps the step incomplete" do
    result = update({ phone: "call me" }, as: user)

    expect(error_codes(result)).to eq(["VALIDATION_FAILED"])
    expect(result.dig("errors", 0, "message")).to start_with("Phone must be a valid phone number")
    expect(user.reload.phone).to be_nil
    expect(onboarding_for(user)["steps"].last["completed"]).to be(false)
  end

  it "does not apply to super admins" do
    expect(onboarding_for(create(:user, :super_admin, first_name: nil, last_name: nil)))
      .to include("required" => false, "completed" => true, "currentStep" => nil)
  end

  it "comes with the user that sign-in returns, so the app knows where to go first" do
    login = <<~GQL
      mutation($email: String!) {
        loginUser(input: { loginAttributes: { email: $email, password: "Passw0rd!" } }) { user { #{onboarding_fields} } }
      }
    GQL

    result = with_feature_disabled(:otp_enabled) { execute_graphql(login, variables: { email: user.email }) }

    expect(result.dig("data", "loginUser", "user", "onboarding", "currentStep")).to eq("step1")
  end

  it "requires a signed-in caller to update" do
    mutation = 'mutation { updateUser(input: { userAttributes: { phone: "+12015550123" } }) { user { id } } }'
    result = execute_graphql(mutation)

    expect(error_codes(result)).to eq(["UNAUTHENTICATED"])
  end

  describe "welcome SMS" do
    it "is sent once, when the save that completes onboarding is made" do
      update({ firstName: "Ada", lastName: "Lovelace" }, as: user)
      expect(SmsLog.count).to eq(0)

      perform_enqueued_jobs { update({ phone: "+1 201 555 0123" }, as: user) }

      expect(SmsLog.sole).to have_attributes(user:, recipient: "+12015550123", message_type: "welcome",
                                             status: "queued", body: include("Welcome", "Ada"))
    end

    it "is not sent again when the phone changes later" do
      perform_enqueued_jobs do
        update({ firstName: "Ada", lastName: "Lovelace", phone: "+12015550123" }, as: user)
        update({ phone: "+12025550199" }, as: user)
      end

      expect(SmsLog.welcome.count).to eq(1)
    end

    it "is not sent to a super admin" do
      admin = create(:user, :super_admin)

      perform_enqueued_jobs { update({ phone: "+12015550123" }, as: admin) }

      expect(SmsLog.count).to eq(0)
    end
  end
end

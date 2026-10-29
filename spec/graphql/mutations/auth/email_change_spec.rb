require "rails_helper"

RSpec.describe "Changing email", type: :graphql do
  let(:user) { create(:user, email: "old@example.com") }
  let(:session) { create(:session, user:) }

  let(:request_mutation) do
    <<~GQL
      mutation($email: String!, $password: String!) {
        requestEmailChange(input: { email: $email, currentPassword: $password }) {
          message
          user { email unconfirmedEmail }
        }
      }
    GQL
  end
  let(:resend_mutation) { "mutation { resendEmailChangeCode(input: {}) { message } }" }
  let(:confirm_mutation) do
    <<~GQL
      mutation($otpCode: String!) { confirmEmailChange(input: { otpCode: $otpCode }) { user { email unconfirmedEmail } } }
    GQL
  end

  def request_change(email: "new@example.com", password: "Passw0rd!")
    perform_enqueued_jobs { execute_graphql(request_mutation, variables: { email:, password: }, session:) }
  end

  def confirm(code)
    perform_enqueued_jobs { execute_graphql(confirm_mutation, variables: { otpCode: code }, session:) }
  end

  it "sends one code, to the new address only, and keeps the old email until it is confirmed" do
    result = request_change

    expect(result.dig("data", "requestEmailChange", "user")).to eq("email" => "old@example.com",
                                                                   "unconfirmedEmail" => "new@example.com")
    expect(ActionMailer::Base.deliveries.flat_map(&:to)).to eq(["new@example.com"])
  end

  it "switches the email with that code and alerts the old address" do
    request_change

    result = confirm(delivered_code_for("new@example.com"))

    expect(result.dig("data", "confirmEmailChange", "user")).to eq("email" => "new@example.com",
                                                                   "unconfirmedEmail" => nil)
    expect(ActionMailer::Base.deliveries.last.to).to eq(["old@example.com"])
    expect(user.reload).to be_email_verified
  end

  it "changes the email immediately and only alerts the old address when email_change_otp_enabled is off" do
    result = with_feature_disabled(:email_change_otp_enabled) { request_change }

    expect(result.dig("data", "requestEmailChange")).to eq(
      "message" => I18n.t("auth.email_changed"),
      "user" => { "email" => "new@example.com", "unconfirmedEmail" => nil }
    )
    expect(user.reload).to have_attributes(email: "new@example.com", email_verified_at: nil)
    expect(ActionMailer::Base.deliveries.sole.to).to eq(["old@example.com"])
  end

  it "rejects a wrong current password and sends nothing" do
    result = request_change(password: "Wrong!pass1")

    expect(error_codes(result)).to eq(["INVALID_CREDENTIALS"])
    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "rejects an address that belongs to another account" do
    create(:user, email: "taken@example.com")

    expect(error_codes(request_change(email: "taken@example.com"))).to eq(["VALIDATION_FAILED"])
  end

  it "rejects a wrong code without changing the email" do
    request_change

    expect(error_codes(confirm("000000"))).to eq(["INVALID_CODE"])
    expect(user.reload.email).to eq("old@example.com")
  end

  it "tells the user to request a new code after too many wrong attempts" do
    request_change
    OneTimePassword::MAX_FAILED_ATTEMPTS.times { confirm("000000") }

    result = confirm(delivered_code_for("new@example.com"))

    expect(result.dig("errors", 0, "message")).to eq(I18n.t("errors.code_locked"))
  end

  it "resends a fresh code after the cooldown, which replaces the previous one" do
    request_change
    first_code = delivered_code_for("new@example.com")

    travel(OneTimePassword::RESEND_COOLDOWN + 1.second) do
      perform_enqueued_jobs { execute_graphql(resend_mutation, session:) }
      new_code = delivered_code_for("new@example.com")

      expect(new_code).not_to eq(first_code)
      expect(error_codes(confirm(first_code))).to eq(["INVALID_CODE"])
    end
  end

  it "refuses a resend inside the cooldown instead of pretending to send" do
    request_change

    expect(error_codes(execute_graphql(resend_mutation, session:))).to eq(["RATE_LIMITED"])
  end

  it "refuses a resend when no change is in progress" do
    expect(error_codes(execute_graphql(resend_mutation, session:))).to eq(["VALIDATION_FAILED"])
  end

  it "is not available while impersonating" do
    impersonated = create(:session, user:, impersonator: create(:user, :super_admin))

    result = execute_graphql(request_mutation, variables: { email: "x@example.com", password: "Passw0rd!" },
                                               session: impersonated)

    expect(error_codes(result)).to eq(["FORBIDDEN"])
  end
end

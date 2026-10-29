require "rails_helper"

RSpec.describe "Password reset", type: :graphql do
  let!(:user) { create(:user) }

  let(:request_mutation) do
    <<~GQL
      mutation($email: String!) { sendResetPasswordInstructions(input: { email: $email }) { message } }
    GQL
  end

  let(:validate_otp_mutation) do
    <<~GQL
      mutation($email: String!, $otpCode: String!) {
        validateOtp(input: { email: $email, otpCode: $otpCode, purpose: password_reset }) { token resetPasswordToken }
      }
    GQL
  end

  let(:set_password_mutation) do
    <<~GQL
      mutation($attributes: ResetPasswordAttributesInput!) {
        setPassword(input: { setPasswordAttributes: $attributes }) { token user { id } }
      }
    GQL
  end

  def reset_token
    perform_enqueued_jobs { execute_graphql(request_mutation, variables: { email: user.email }) }
    result = execute_graphql(validate_otp_mutation,
                             variables: { email: user.email, otpCode: delivered_code_for(user.email) })
    result.dig("data", "validateOtp", "resetPasswordToken")
  end

  def set_password(token, password: "N3w!password")
    execute_graphql(set_password_mutation, variables: {
                      attributes: { resetPasswordToken: token, password:, passwordConfirmation: password }
                    })
  end

  it "responds the same whether or not the account exists" do
    known = execute_graphql(request_mutation, variables: { email: user.email })
    unknown = execute_graphql(request_mutation, variables: { email: "nobody@example.com" })

    expect(unknown).to eq(known)
  end

  it "exchanges the emailed code for a reset token but no session" do
    perform_enqueued_jobs { execute_graphql(request_mutation, variables: { email: user.email }) }
    result = execute_graphql(validate_otp_mutation,
                             variables: { email: user.email, otpCode: delivered_code_for(user.email) })

    expect(result.dig("data", "validateOtp")).to include("token" => nil, "resetPasswordToken" => be_present)
  end

  it "sets the new password, signs out other devices and starts a session" do
    old_session = create(:session, user:)

    payload = set_password(reset_token).dig("data", "setPassword")

    expect(user.reload.authenticate("N3w!password")).to be_truthy
    expect(Session.find_by_token(payload["token"]).user).to eq(user)
    expect(Session.exists?(old_session.id)).to be(false)
  end

  def start_login
    perform_enqueued_jobs do
      execute_graphql(<<~GQL, variables: { email: user.email, password: "Passw0rd!" })
        mutation($email: String!, $password: String!) {
          loginUser(input: { loginAttributes: { email: $email, password: $password } }) { message }
        }
      GQL
    end
  end

  it "keeps the reset screen on its own code when a login is started afterwards" do
    perform_enqueued_jobs { execute_graphql(request_mutation, variables: { email: user.email }) }
    start_login

    travel(OneTimePassword::RESEND_COOLDOWN + 1.second) do
      perform_enqueued_jobs do
        execute_graphql(<<~GQL, variables: { email: user.email })
          mutation($email: String!) { resendOtp(input: { email: $email, purpose: password_reset }) { message } }
        GQL
      end
      result = execute_graphql(<<~GQL, variables: { email: user.email, otpCode: delivered_code_for(user.email) })
        mutation($email: String!, $otpCode: String!) {
          validateOtp(input: { email: $email, otpCode: $otpCode, purpose: password_reset }) { token resetPasswordToken }
        }
      GQL

      expect(result.dig("data", "validateOtp")).to include("token" => nil, "resetPasswordToken" => be_present)
    end
  end

  it "refuses to reuse a reset token" do
    token = reset_token
    set_password(token)

    expect(error_codes(set_password(token, password: "An0ther!pass"))).to eq(["INVALID_TOKEN"])
  end

  it "rejects a made-up token" do
    expect(error_codes(set_password("forged"))).to eq(["INVALID_TOKEN"])
  end
end

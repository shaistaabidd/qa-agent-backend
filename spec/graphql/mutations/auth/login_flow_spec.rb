require "rails_helper"

RSpec.describe "Registration and login", type: :graphql do
  let(:register_mutation) do
    <<~GQL
      mutation($attributes: RegisterAttributesInput!) {
        registerUser(input: { registerAttributes: $attributes }) { message }
      }
    GQL
  end

  let(:login_mutation) do
    <<~GQL
      mutation($email: String!, $password: String!) {
        loginUser(input: { loginAttributes: { email: $email, password: $password } }) { message }
      }
    GQL
  end

  let(:validate_otp_mutation) do
    <<~GQL
      mutation($email: String!, $otpCode: String!) {
        validateOtp(input: { email: $email, otpCode: $otpCode, purpose: login }) {
          token
          resetPasswordToken
          user { id email role }
        }
      }
    GQL
  end

  let(:resend_otp_mutation) do
    <<~GQL
      mutation($email: String!) { resendOtp(input: { email: $email, purpose: login }) { message } }
    GQL
  end

  describe "registerUser" do
    let(:attributes) { { email: "new@example.com", password: "Passw0rd!", passwordConfirmation: "Passw0rd!" } }

    it "creates a regular user and emails a login code" do
      result = perform_enqueued_jobs { execute_graphql(register_mutation, variables: { attributes: }) }

      expect(result.dig("data", "registerUser", "message")).to eq(I18n.t("auth.verification_code_sent"))
      expect(User.find_by(email: "new@example.com")).to be_user
      expect(delivered_code_for("new@example.com")).to match(/\A\d{6}\z/)
    end

    it "explains what is wrong with the password without echoing it" do
      result = execute_graphql(register_mutation,
                               variables: { attributes: attributes.merge(password: "weak",
                                                                         passwordConfirmation: "weak") })

      expect(error_codes(result)).to eq(["VALIDATION_FAILED"])
      expect(result["errors"].sole).to include("extensions" => { "code" => "VALIDATION_FAILED" })
      expect(result.dig("errors", 0, "message")).to include("Password is too short")
      expect(result.to_json).not_to include("weak")
    end

    it "answers a taken email exactly like a new one and warns the owner instead" do
      create(:user, email: "taken@example.com")

      result = perform_enqueued_jobs do
        execute_graphql(register_mutation, variables: { attributes: attributes.merge(email: "TAKEN@example.com") })
      end

      expect(result).to eq("data" => { "registerUser" => { "message" => I18n.t("auth.verification_code_sent") } })
      expect(ActionMailer::Base.deliveries.sole.subject).to include("Sign-up attempt")
    end

    it "still reports other errors for a taken email, without mentioning the email" do
      create(:user, email: "taken@example.com")

      result = execute_graphql(register_mutation, variables: {
                                 attributes: attributes.merge(email: "taken@example.com", password: "weak",
                                                              passwordConfirmation: "weak")
                               })

      message = result.dig("errors", 0, "message")
      expect(message).to include("Password")
      expect(message).not_to include("Email")
    end

    it "cannot be used to create a super admin" do
      result = execute_graphql(register_mutation, variables: { attributes: attributes.merge(role: "super_admin") })

      expect(result["errors"]).to be_present
      expect(User.super_admin).to be_empty
    end

    it "is refused while sign-up is turned off" do
      result = with_feature_disabled(:sign_up_enabled) do
        execute_graphql(register_mutation, variables: { attributes: })
      end

      expect(error_codes(result)).to eq(["SIGN_UP_DISABLED"])
      expect(User.find_by(email: attributes[:email])).to be_nil
    end

    it "still confirms a new account by code when otp_enabled is off, answering like a taken email" do
      create(:user, email: "taken@example.com")

      new_result, taken_result = with_feature_disabled(:otp_enabled) do
        perform_enqueued_jobs do
          [execute_graphql(register_mutation, variables: { attributes: }),
           execute_graphql(register_mutation, variables: { attributes: attributes.merge(email: "taken@example.com") })]
        end
      end

      expect(new_result).to eq(taken_result)
      expect(Session.count).to eq(0)
      expect(delivered_code_for(attributes[:email])).to match(/\A\d{6}\z/)
    end

    it "verifies the new account's email once its code is confirmed" do
      perform_enqueued_jobs { execute_graphql(register_mutation, variables: { attributes: }) }
      user = User.find_by!(email: attributes[:email])
      expect(user).not_to be_email_verified

      execute_graphql(validate_otp_mutation, variables: { email: user.email, otpCode: delivered_code_for(user.email) })

      expect(user.reload).to be_email_verified
    end
  end

  describe "loginUser then validateOtp" do
    let!(:user) { create(:user, email: "jane@example.com") }

    def request_code(email: "jane@example.com", password: "Passw0rd!")
      perform_enqueued_jobs { execute_graphql(login_mutation, variables: { email:, password: }) }
    end

    it "returns a working session token for the right code" do
      request_code
      result = execute_graphql(validate_otp_mutation,
                               variables: { email: "jane@example.com", otpCode: delivered_code_for(user.email) })

      payload = result.dig("data", "validateOtp")
      expect(payload["user"]).to include("id" => user.id.to_s, "role" => "user")
      expect(Session.find_by_token(payload["token"]).user).to eq(user)
      expect(payload["resetPasswordToken"]).to be_nil
    end

    it "accepts the email in any letter case" do
      expect(request_code(email: "JANE@example.com").dig("data", "loginUser", "message")).to be_present
    end

    it "rejects a wrong password with a generic message" do
      result = request_code(password: "Wrong-pass1")

      expect(error_codes(result)).to eq(["INVALID_CREDENTIALS"])
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "rejects an unknown email with the same message as a wrong password" do
      wrong_password = request_code(password: "Wrong-pass1")
      unknown_email = request_code(email: "nobody@example.com")

      expect(unknown_email.dig("errors", 0, "message")).to eq(wrong_password.dig("errors", 0, "message"))
    end

    it "refuses a user whose access was revoked" do
      user.revoke_access!

      expect(error_codes(request_code)).to eq(["ACCESS_REVOKED"])
    end

    it "rejects a wrong code" do
      request_code
      result = execute_graphql(validate_otp_mutation, variables: { email: user.email, otpCode: "000000" })

      expect(error_codes(result)).to eq(["INVALID_CODE"])
    end

    it "tells the user to request a new code after too many wrong attempts" do
      request_code
      results = Array.new(OneTimePassword::MAX_FAILED_ATTEMPTS) do
        execute_graphql(validate_otp_mutation, variables: { email: user.email, otpCode: "000000" })
      end
      locked = execute_graphql(validate_otp_mutation,
                               variables: { email: user.email, otpCode: delivered_code_for(user.email) })

      expect(results.first.dig("errors", 0, "message")).to eq(I18n.t("errors.invalid_code"))
      expect(locked.dig("errors", 0, "message")).to eq(I18n.t("errors.code_locked"))
    end

    it "rejects a code that was already used" do
      request_code
      code = delivered_code_for(user.email)
      execute_graphql(validate_otp_mutation, variables: { email: user.email, otpCode: code })

      result = execute_graphql(validate_otp_mutation, variables: { email: user.email, otpCode: code })

      expect(error_codes(result)).to eq(["INVALID_CODE"])
    end

    it "rate limits code guesses per email" do
      request_code
      results = Array.new(11) do
        execute_graphql(validate_otp_mutation, variables: { email: user.email, otpCode: "000000" })
      end

      expect(error_codes(results.last)).to eq(["RATE_LIMITED"])
    end

    it "limits password guesses per IP, even with many emails aliased into one request" do
      aliased = Array.new(31) do |n|
        attributes = %(email: "guess#{n}@example.com", password: "Wrong-pass1")
        %(login#{n}: loginUser(input: { loginAttributes: { #{attributes} } }) { message })
      end

      result = execute_graphql("mutation { #{aliased.join(" ")} }")

      expect(error_codes(result)).to include("RATE_LIMITED")
      expect(result["errors"].count { it.dig("extensions", "code") == "RATE_LIMITED" }).to eq(1)
    end

    it "counts password guesses per email whatever its letter case or spacing" do
      variants = ["jane@example.com", "JANE@example.com", " Jane@Example.com "]
      results = Array.new(11) { request_code(email: variants[it % variants.size], password: "Wrong-pass1") }

      expect(error_codes(results.last)).to eq(["RATE_LIMITED"])
    end

    it "signs the user in immediately when otp_enabled is off" do
      query = <<~GQL
        mutation($email: String!, $password: String!) {
          loginUser(input: { loginAttributes: { email: $email, password: $password } }) {
            message
            token
            user { id email role }
          }
        }
      GQL

      result = with_feature_disabled(:otp_enabled) do
        perform_enqueued_jobs { execute_graphql(query, variables: { email: user.email, password: "Passw0rd!" }) }
      end

      payload = result.dig("data", "loginUser")
      expect(payload["message"]).to eq(I18n.t("auth.signed_in"))
      expect(payload["user"]).to include("id" => user.id.to_s, "role" => "user")
      expect(Session.find_by_token(payload["token"]).user).to eq(user)
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end

  describe "resendOtp" do
    let!(:user) { create(:user) }

    it "sends a fresh code after the cooldown" do
      perform_enqueued_jobs { execute_graphql(login_mutation, variables: { email: user.email, password: "Passw0rd!" }) }

      travel(OneTimePassword::RESEND_COOLDOWN + 1.second) do
        perform_enqueued_jobs { execute_graphql(resend_otp_mutation, variables: { email: user.email }) }
      end

      expect(ActionMailer::Base.deliveries.size).to eq(2)
    end

    it "says so instead of pretending, when there is no login to resend" do
      result = perform_enqueued_jobs { execute_graphql(resend_otp_mutation, variables: { email: user.email }) }

      expect(error_codes(result)).to eq(["INVALID_CODE"])
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end
end

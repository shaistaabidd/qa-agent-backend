require "rails_helper"

# Each flag switched on for one role only, through the real API: the role it is
# on for gets the flagged behavior, every other role gets the "off" behavior.
RSpec.describe "Feature flags by role", type: :graphql do
  let(:user) { create(:user, email: "member@example.com") }
  let(:admin) { create(:user, :super_admin, email: "admin@example.com") }

  describe "sign_up_enabled" do
    let(:mutation) do
      <<~GQL
        mutation($attributes: RegisterAttributesInput!) {
          registerUser(input: { registerAttributes: $attributes }) { message }
        }
      GQL
    end
    let(:attributes) { { email: "new@example.com", password: "Passw0rd!", passwordConfirmation: "Passw0rd!" } }

    it "lets people sign up when it is on for the role sign-up creates" do
      result = with_feature_scoped_to_role(:sign_up_enabled, User::SIGN_UP_ROLE) do
        execute_graphql(mutation, variables: { attributes: })
      end

      expect(result["errors"]).to be_nil
      expect(User.find_by(email: "new@example.com")).to be_user
    end

    it "refuses sign-up when it is not on for the role sign-up creates" do
      result = with_feature_disabled(:sign_up_enabled) do
        execute_graphql(mutation, variables: { attributes: })
      end

      expect(error_codes(result)).to eq(["SIGN_UP_DISABLED"])
      expect(User.find_by(email: "new@example.com")).to be_nil
    end
  end

  describe "otp_enabled" do
    let(:mutation) do
      <<~GQL
        mutation($email: String!, $password: String!) {
          loginUser(input: { loginAttributes: { email: $email, password: $password } }) { message token }
        }
      GQL
    end

    def log_in(person)
      perform_enqueued_jobs { execute_graphql(mutation, variables: { email: person.email, password: "Passw0rd!" }) }
    end

    it "emails a code to a role it is on for and signs another role in immediately" do
      user_result, admin_result = with_feature_scoped_to_role(:otp_enabled, :user) { [log_in(user), log_in(admin)] }

      expect(user_result.dig("data", "loginUser")).to eq("message" => I18n.t("auth.verification_code_sent"),
                                                         "token" => nil)
      expect(delivered_code_for(user.email)).to match(/\A\d{6}\z/)
      expect(Session.find_by_token(admin_result.dig("data", "loginUser", "token")).user).to eq(admin)
      expect(delivered_code_for(admin.email)).to be_nil
    end

    it "keeps the code step for one user switched on individually, whatever their role" do
      other = create(:user)
      results = with_feature_scoped_to_actor(:otp_enabled, user) { [log_in(user), log_in(other)] }

      expect(results.map { it.dig("data", "loginUser", "token").present? }).to eq([false, true])
    end
  end

  describe "email_change_otp_enabled" do
    let(:mutation) do
      <<~GQL
        mutation($email: String!) {
          requestEmailChange(input: { email: $email, currentPassword: "Passw0rd!" }) { user { email unconfirmedEmail } }
        }
      GQL
    end

    def change_email(person, to)
      perform_enqueued_jobs { execute_graphql(mutation, variables: { email: to }, as: person) }
    end

    it "requires a code for a role it is on for and changes another role's email at once" do
      user_result, admin_result = with_feature_scoped_to_role(:email_change_otp_enabled, :user) do
        [change_email(user, "member.new@example.com"), change_email(admin, "admin.new@example.com")]
      end

      expect(user_result.dig("data", "requestEmailChange", "user"))
        .to eq("email" => "member@example.com", "unconfirmedEmail" => "member.new@example.com")
      expect(admin_result.dig("data", "requestEmailChange", "user"))
        .to eq("email" => "admin.new@example.com", "unconfirmedEmail" => nil)
    end
  end

  describe "email_change_otp_enabled switched off mid-change" do
    it "drops the pending address and its code when the email then changes at once" do
      session = create(:session, user:)
      request = lambda do |to|
        perform_enqueued_jobs do
          execute_graphql(<<~GQL, variables: { email: to }, session:)
            mutation($email: String!) {
              requestEmailChange(input: { email: $email, currentPassword: "Passw0rd!" }) { user { email unconfirmedEmail } }
            }
          GQL
        end
      end
      request.call("pending@example.com")
      code = delivered_code_for("pending@example.com")

      result = with_feature_disabled(:email_change_otp_enabled) { request.call("direct@example.com") }
      confirm_mutation = "mutation($c: String!) { confirmEmailChange(input: { otpCode: $c }) { user { email } } }"
      confirm = execute_graphql(confirm_mutation, variables: { c: code }, session:)

      expect(result.dig("data", "requestEmailChange", "user"))
        .to eq("email" => "direct@example.com", "unconfirmedEmail" => nil)
      expect(confirm["errors"]).to be_present
      expect(user.reload.email).to eq("direct@example.com")
    end
  end

  describe "invitations_enabled" do
    let(:mutation) do
      <<~GQL
        mutation($emails: [String!]!, $role: UserRoleEnum!) {
          createInvitation(input: { emails: $emails, role: $role }) { message }
        }
      GQL
    end

    def invite(email, role) = execute_graphql(mutation, variables: { emails: [email], role: }, as: admin)

    it "lets an admin invite a role it is on for, and forbids a role it is not on for" do
      allowed = with_feature_scoped_to_role(:invitations_enabled, :user) { invite("a@example.com", "user") }
      forbidden = with_feature_disabled(:invitations_enabled) { invite("b@example.com", "user") }

      expect(allowed["errors"]).to be_nil
      expect(error_codes(forbidden)).to eq(["FORBIDDEN"])
    end

    it "never lets anyone be invited as a super admin, even with the flag fully on" do
      expect(Flipper[:invitations_enabled].boolean_value).to be(true)
      expect(error_codes(invite("c@example.com", "super_admin"))).to eq(["FORBIDDEN"])
      expect(User.find_by(email: "c@example.com")).to be_nil
    end
  end

  describe "impersonation_enabled" do
    let(:mutation) { "mutation($id: ID!) { impersonateUser(input: { userId: $id }) { token } }" }

    def impersonate(person) = execute_graphql(mutation, variables: { id: person.id }, as: admin)

    it "lets a super admin impersonate a role it is on for, and forbids it otherwise" do
      allowed = with_feature_scoped_to_role(:impersonation_enabled, :user) { impersonate(user) }
      forbidden = with_feature_disabled(:impersonation_enabled) { impersonate(user) }

      expect(allowed.dig("data", "impersonateUser", "token")).to be_present
      expect(error_codes(forbidden)).to eq(["FORBIDDEN"])
    end

    it "follows a flag switched on for one user" do
      other = create(:user)
      results = with_feature_scoped_to_actor(:impersonation_enabled, user) { [impersonate(user), impersonate(other)] }

      expect(results.map { error_codes(it) }).to eq([[], ["FORBIDDEN"]])
    end

    it "is reported per user on allUsers, so the admin list can show who may be impersonated" do
      other = create(:user, email: "other@example.com")
      query = "{ allUsers(filters: { role: user }) { allData { email featureFlags { impersonationEnabled } } } }"

      rows = with_feature_scoped_to_actor(:impersonation_enabled, user) do
        execute_graphql(query, as: admin).dig("data", "allUsers", "allData")
      end

      expect(rows.to_h { [it["email"], it.dig("featureFlags", "impersonationEnabled")] })
        .to eq(user.email => true, other.email => false)
    end

    it "never allows impersonating a super admin, even with the flag fully on" do
      expect(error_codes(impersonate(create(:user, :super_admin)))).to eq(["FORBIDDEN"])
    end
  end

  describe "sms_enabled" do
    let(:mutation) do
      <<~GQL
        mutation($attributes: UserAttributesInput!) {
          updateUser(input: { userAttributes: $attributes }) { user { id } }
        }
      GQL
    end

    def complete_onboarding(person)
      person.update!(phone: nil)
      perform_enqueued_jobs do
        execute_graphql(mutation, variables: { attributes: { phone: "+12015550123" } }, as: person)
      end
    end

    it "texts the welcome SMS to a role it is on for, and not to another" do
      member = create(:user, phone: nil)
      with_feature_scoped_to_role(:sms_enabled, :user) { complete_onboarding(member) }
      other = create(:user, phone: nil)
      with_feature_disabled(:sms_enabled) { complete_onboarding(other) }

      expect(SmsLog.welcome.pluck(:user_id)).to eq([member.id])
      expect(a_request(:post, twilio_messages_url)).to have_been_made.once
    end
  end

  describe "User.featureFlags" do
    let(:flag_fields) do
      "featureFlags { signUpEnabled otpEnabled emailChangeOtpEnabled invitationsEnabled impersonationEnabled }"
    end

    def login_mutation(selection)
      <<~GQL
        mutation($email: String!) {
          loginUser(input: { loginAttributes: { email: $email, password: "Passw0rd!" } }) { #{selection} }
        }
      GQL
    end

    def own_flags(person)
      execute_graphql("{ fetchUser { #{flag_fields} } }", as: person).dig("data", "fetchUser", "featureFlags")
    end

    it "comes with fetchUser, resolved for that user's role" do
      with_feature_scoped_to_role(:email_change_otp_enabled, :super_admin) do
        expect([own_flags(admin), own_flags(user)].pluck("emailChangeOtpEnabled")).to eq([true, false])
      end
    end

    it "comes with the user a code-less login returns, so the app has flags from the first screen" do
      result = with_feature_disabled(:otp_enabled) do
        execute_graphql(login_mutation("user { #{flag_fields} }"), variables: { email: user.email })
      end

      expect(result.dig("data", "loginUser", "user", "featureFlags"))
        .to eq("signUpEnabled" => true, "otpEnabled" => false, "emailChangeOtpEnabled" => true,
               "invitationsEnabled" => true, "impersonationEnabled" => true)
    end

    it "comes with the user validateOtp returns" do
      perform_enqueued_jobs { execute_graphql(login_mutation("message"), variables: { email: user.email }) }
      query = <<~GQL
        mutation($email: String!, $code: String!) {
          validateOtp(input: { email: $email, otpCode: $code, purpose: login }) { user { #{flag_fields} } }
        }
      GQL

      result = execute_graphql(query, variables: { email: user.email, code: delivered_code_for(user.email) })

      expect(result.dig("data", "validateOtp", "user", "featureFlags", "otpEnabled")).to be(true)
    end
  end

  describe "fetchPublicFeatureFlags" do
    let(:query) { "{ fetchPublicFeatureFlags { signUpEnabled otpEnabled } }" }

    def public_flags = execute_graphql(query).dig("data", "fetchPublicFeatureFlags")

    it "tells a signed-out visitor whether sign-up is open and whether a code is needed" do
      expect(public_flags).to eq("signUpEnabled" => true, "otpEnabled" => true)
    end

    it "answers for the role public sign-up creates, which the server picks" do
      with_feature_scoped_to_role(:otp_enabled, :super_admin) { expect(public_flags["otpEnabled"]).to be(false) }
      with_feature_scoped_to_role(:otp_enabled, User::SIGN_UP_ROLE) { expect(public_flags["otpEnabled"]).to be(true) }
      with_feature_disabled(:sign_up_enabled) { expect(public_flags["signUpEnabled"]).to be(false) }
    end

    it "exposes nothing else: no other flag and no role to ask about" do
      other_flag = execute_graphql("{ fetchPublicFeatureFlags { invitationsEnabled } }")
      other_role = execute_graphql("{ fetchPublicFeatureFlags(role: super_admin) { signUpEnabled } }")

      expect(other_flag["errors"].first["message"]).to include("invitationsEnabled")
      expect(other_role["errors"].first["message"]).to include("role")
    end
  end

  describe "fetchFeatureFlags" do
    let(:query) do
      <<~GQL
        query($role: UserRoleEnum) {
          fetchFeatureFlags(role: $role) {
            signUpEnabled otpEnabled emailChangeOtpEnabled invitationsEnabled impersonationEnabled
          }
        }
      GQL
    end

    def flags(as:, role: nil) = execute_graphql(query, variables: { role: }, as:).dig("data", "fetchFeatureFlags")

    it "requires sign-in" do
      expect(error_codes(execute_graphql(query))).to eq(["UNAUTHENTICATED"])
    end

    it "returns every flag as a boolean for the signed-in user" do
      expect(flags(as: user)).to eq("signUpEnabled" => true, "otpEnabled" => true, "emailChangeOtpEnabled" => true,
                                    "invitationsEnabled" => true, "impersonationEnabled" => true)
    end

    it "follows the signed-in user's role" do
      with_feature_scoped_to_role(:otp_enabled, :super_admin) do
        expect(flags(as: admin)["otpEnabled"]).to be(true)
        expect(flags(as: user)["otpEnabled"]).to be(false)
      end
    end

    it "answers for a given role, e.g. whether users of that role can be invited or impersonated" do
      with_feature_scoped_to_role(:invitations_enabled, :user) do
        expect(flags(as: admin, role: "user")["invitationsEnabled"]).to be(true)
      end
    end

    it "is always false for super admin sign-up, invitations and impersonation, even fully on" do
      expect(flags(as: admin, role: "super_admin")).to include("signUpEnabled" => false, "invitationsEnabled" => false,
                                                               "impersonationEnabled" => false)
      expect(flags(as: admin)).to include("signUpEnabled" => false, "otpEnabled" => true)
    end

    it "follows a flag switched on for one user" do
      with_feature_scoped_to_actor(:otp_enabled, user) do
        expect(flags(as: user)["otpEnabled"]).to be(true)
        expect(flags(as: create(:user))["otpEnabled"]).to be(false)
      end
    end
  end

  describe "google_sign_in_enabled" do
    before { stub_google_profile(email: admin.email) }

    def google_sign_in
      execute_graphql(sign_in_with_google_mutation,
                      variables: { code: google_handoff_code,
                                   nonce: GoogleOauthHelper::GOOGLE_NONCE })
    end

    it "signs in a role it is on for and refuses another role" do
      admin_result = with_feature_scoped_to_role(:google_sign_in_enabled, :user) { google_sign_in }
      stub_google_profile(email: user.email, sub: "google-uid-2")
      user_result = with_feature_scoped_to_role(:google_sign_in_enabled, :user) { google_sign_in }

      expect(error_codes(admin_result)).to eq(["GOOGLE_SIGN_IN_DISABLED"])
      expect(user_result.dig("data", "signInWithGoogle", "user", "id")).to eq(user.id.to_s)
    end

    it "lets a super admin sign in with Google when it is on for super admins" do
      result = with_feature_scoped_to_role(:google_sign_in_enabled, :super_admin) { google_sign_in }

      expect(result.dig("data", "signInWithGoogle", "user")).to include("id" => admin.id.to_s, "role" => "super_admin")
    end

    it "creates a new account only while it is on for the role sign-up creates" do
      stub_google_profile(email: "newcomer@example.com", sub: "google-uid-3")

      result = with_feature_scoped_to_role(:google_sign_in_enabled, :super_admin) { google_sign_in }

      expect(error_codes(result)).to eq(["GOOGLE_SIGN_IN_DISABLED"])
      expect(User.find_by(email: "newcomer@example.com")).to be_nil
    end
  end
end

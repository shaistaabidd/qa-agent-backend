require "rails_helper"

RSpec.describe "signInWithGoogle", type: :graphql do
  def redeem(code, nonce: GoogleOauthHelper::GOOGLE_NONCE)
    execute_graphql(sign_in_with_google_mutation, variables: { code:, nonce: })
  end

  def error_message(result) = result.dig("errors", 0, "message")

  before { stub_google_profile }

  context "with an email that has no account" do
    it "creates a regular user without a password and signs them in, with no emailed code" do
      result = perform_enqueued_jobs { redeem(google_handoff_code) }

      payload = result.dig("data", "signInWithGoogle")
      user = User.find_by!(email: "ada@example.com")
      expect(payload).to eq("message" => I18n.t("auth.signed_in"), "token" => payload["token"],
                            "user" => { "id" => user.id.to_s, "email" => "ada@example.com", "role" => "user" })
      expect(Session.find_by_token(payload["token"]).user).to eq(user)
      expect(user).to have_attributes(first_name: "Ada", last_name: "Lovelace", google_uid: "google-uid-1",
                                      email_verified_at: be_present,
                                      password_digest: nil, last_sign_in_at: be_present)
      expect(user.onboarding.current_step.name).to eq(:step2)
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "queues copying the Google photo" do
      stub_google_profile(picture: "https://lh3.googleusercontent.com/a/photo-id=s96-c")

      expect { redeem(google_handoff_code) }.to have_enqueued_job(AttachGooglePictureJob)
        .with(kind_of(Integer), "https://lh3.googleusercontent.com/a/photo-id=s96-c")
    end

    it "fills the phone from Google, which finishes onboarding and sends the welcome SMS" do
      stub_google_people(person: google_person)

      redeem(google_handoff_code)

      user = User.find_by!(email: "ada@example.com")
      expect(user.phone).to eq("+12015550123")
      expect(user.onboarding).to be_completed
      expect(SmsLog.welcome.sole).to have_attributes(user:, recipient: "+12015550123")
    end

    it "leaves a phone Google holds without a country code for onboarding to ask" do
      stub_google_people(person: google_person(phone: "2015550123"))

      redeem(google_handoff_code)

      expect(User.find_by!(email: "ada@example.com")).to have_attributes(phone: nil)
      expect(SmsLog.count).to eq(0)
    end

    it "still creates the account when Google won't share phone and birthday" do
      stub_google_people(status: 403, person: { error: { code: 403 } })

      result = redeem(google_handoff_code)

      expect(result["errors"]).to be_nil
      expect(User.find_by!(email: "ada@example.com")).to have_attributes(first_name: "Ada", phone: nil)
    end

    it "does not call the People API while it is switched off" do
      allow(Rails.configuration.x).to receive(:google_oauth)
        .and_return(Rails.configuration.x.google_oauth.merge(people_details: false))

      redeem(google_handoff_code)

      expect(a_request(:get, GoogleOauth::Client::PEOPLE_URL.to_s)).not_to have_been_made
      expect(User.find_by!(email: "ada@example.com").phone).to be_nil
    end

    it "is refused while sign-up is turned off" do
      result = with_feature_disabled(:sign_up_enabled) { redeem(google_handoff_code) }

      expect(error_codes(result)).to eq(["SIGN_UP_DISABLED"])
      expect(User.find_by(email: "ada@example.com")).to be_nil
    end
  end

  context "with an existing account" do
    let!(:user) { create(:user, email: "ada@example.com") }

    it "never links an account whose email was never confirmed (it may have been registered by someone else)" do
      user.update!(email_verified_at: nil)

      result = redeem(google_handoff_code)

      expect(error_codes(result)).to eq(["GOOGLE_SIGN_IN_FAILED"])
      expect(result.dig("errors", 0, "message")).to eq(I18n.t("errors.google_email_unconfirmed"))
      expect(user.reload.google_uid).to be_nil
    end

    it "signs in an account with the same email and links it to the Google account" do
      result = redeem(google_handoff_code)

      expect(result.dig("data", "signInWithGoogle", "user", "id")).to eq(user.id.to_s)
      expect(user.reload.google_uid).to eq("google-uid-1")
      expect(User.authenticate_by(email: user.email, password: "Passw0rd!")).to eq(user)
    end

    it "never overwrites what the account already has, and asks Google for nothing more" do
      user.update!(first_name: "Augusta", last_name: "King", phone: nil)
      stub_google_profile(picture: "https://lh3.googleusercontent.com/a/photo-id=s96-c")
      stub_google_people(person: google_person)

      expect { redeem(google_handoff_code) }.not_to have_enqueued_job(AttachGooglePictureJob)

      expect(user.reload).to have_attributes(first_name: "Augusta", last_name: "King", phone: nil)
      expect(a_request(:get, GoogleOauth::Client::PEOPLE_URL.to_s)).not_to have_been_made
    end

    it "keeps finding a linked account after its Google email changes" do
      user.update!(google_uid: "google-uid-1")
      stub_google_profile(email: "ada.new@example.com")

      expect(redeem(google_handoff_code).dig("data", "signInWithGoogle", "user", "id")).to eq(user.id.to_s)
    end

    it "refuses an account already linked to a different Google account" do
      user.update!(google_uid: "another-google-uid")

      result = redeem(google_handoff_code)

      expect(error_codes(result)).to eq(["GOOGLE_SIGN_IN_FAILED"])
      expect(error_message(result)).to eq(I18n.t("errors.google_account_mismatch"))
    end

    it "refuses an account whose access was revoked" do
      user.revoke_access!

      result = redeem(google_handoff_code)

      expect(error_codes(result)).to eq(["ACCESS_REVOKED"])
      expect(error_message(result)).to eq(I18n.t("errors.sign_in_blocked.access_revoked"))
    end

    it "refuses an account whose access is revoked after Google's callback" do
      code = google_handoff_code
      user.revoke_access!

      expect(error_codes(redeem(code))).to eq(["ACCESS_REVOKED"])
    end

    it "refuses an invited user who has not accepted yet" do
      user.update_columns(password_digest: nil, invitation_sent_at: Time.current)

      expect(error_message(redeem(google_handoff_code))).to eq(I18n.t("errors.sign_in_blocked.invitation_pending"))
    end
  end

  it "is refused while google_sign_in_enabled is off" do
    result = with_feature_disabled(:google_sign_in_enabled) { redeem(google_handoff_code) }

    expect(error_codes(result)).to eq(["GOOGLE_SIGN_IN_DISABLED"])
    expect(User.find_by(email: "ada@example.com")).to be_nil
  end

  it "is refused when Google is not configured" do
    allow(Rails.configuration.x).to receive(:google_oauth)
      .and_return(Rails.configuration.x.google_oauth.merge(client_secret: nil))

    back_to_frontend = Auth::StartGoogleSignIn.call(nonce: GoogleOauthHelper::GOOGLE_NONCE).value

    expect(back_to_frontend).to start_with(Rails.configuration.x.frontend_url)
    expect(error_codes(redeem(fragment_param(back_to_frontend, "code")))).to eq(["GOOGLE_SIGN_IN_DISABLED"])
  end

  it "refuses a Google account whose email is not verified" do
    stub_google_profile(email_verified: false)

    result = redeem(google_handoff_code)

    expect(error_message(result)).to eq(I18n.t("errors.google_email_unverified"))
    expect(User.find_by(email: "ada@example.com")).to be_nil
  end

  it "reports a sign-in cancelled at Google without calling Google" do
    result = redeem(google_handoff_code(code: nil, error: "access_denied"))

    expect(error_message(result)).to eq(I18n.t("errors.google_sign_in_cancelled"))
    expect(a_request(:post, GoogleOauth::Client::TOKEN_URL.to_s)).not_to have_been_made
  end

  it "reports a code Google refuses, without passing on Google's answer" do
    stub_google_profile(token_status: 400)

    result = redeem(google_handoff_code)

    expect(result["errors"].sole).to include("message" => I18n.t("errors.google_sign_in_failed"),
                                             "extensions" => { "code" => "GOOGLE_SIGN_IN_FAILED" })
  end

  it "sends PKCE's verifier and the client secret to Google, never to the browser" do
    google_url = Auth::StartGoogleSignIn.call(nonce: GoogleOauthHelper::GOOGLE_NONCE).value
    Auth::CompleteGoogleSignIn.call(state: query_param(google_url, "state"), code: "google-auth-code", error: nil)

    expect(google_url).not_to include("test-client-secret")
    expect(a_request(:post, GoogleOauth::Client::TOKEN_URL.to_s).with do |request|
      form = Rack::Utils.parse_query(request.body)
      challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(form["code_verifier"]), padding: false)
      form["client_secret"] == "test-client-secret" && challenge == query_param(google_url, "code_challenge")
    end).to have_been_made.once
  end

  describe "one-time values" do
    it "signs in only the browser holding the nonce that started the sign-in" do
      result = redeem(google_handoff_code, nonce: "someone-elses-nonce")

      expect(error_codes(result)).to eq(["GOOGLE_SIGN_IN_FAILED"])
      expect(Session.count).to eq(0)
    end

    it "accepts the code once" do
      code = google_handoff_code
      redeem(code)

      expect(error_message(redeem(code))).to eq(I18n.t("errors.google_sign_in_expired"))
    end

    it "expires the code after a minute" do
      code = google_handoff_code

      travel(Auth::GoogleSignIn::HANDOFF_TTL + 1.second) do
        expect(error_message(redeem(code))).to eq(I18n.t("errors.google_sign_in_expired"))
      end
    end

    it "refuses Google's callback replayed with the same state" do
      google_url = Auth::StartGoogleSignIn.call(nonce: GoogleOauthHelper::GOOGLE_NONCE).value
      state = query_param(google_url, "state")
      Auth::CompleteGoogleSignIn.call(state:, code: "google-auth-code", error: nil)

      replay = Auth::CompleteGoogleSignIn.call(state:, code: "google-auth-code", error: nil).value

      expect(error_message(redeem(fragment_param(replay, "code")))).to eq(I18n.t("errors.google_sign_in_expired"))
    end
  end

  it "rate limits redemptions per IP" do
    results = Array.new(11) { redeem("not-a-code") }

    expect(error_codes(results.last)).to eq(["RATE_LIMITED"])
  end
end

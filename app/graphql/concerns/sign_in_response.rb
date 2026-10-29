module SignInResponse
  extend ActiveSupport::Concern

  private

  # Shared by registerUser and loginUser: both hand back an Auth::SignInOutcome,
  # and respond the same way whether a session was granted immediately
  # (otp_enabled off) or a login code was emailed instead (see Auth::GrantsAccess).
  def sign_in_payload(outcome)
    if outcome.session
      { message: I18n.t("auth.signed_in"), token: outcome.session.token, user: outcome.user }
    else
      { message: I18n.t("auth.verification_code_sent"), token: nil, user: nil }
    end
  end
end

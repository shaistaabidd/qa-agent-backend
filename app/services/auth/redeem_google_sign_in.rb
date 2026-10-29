module Auth
  # Last leg of Sign in with Google: turns the one-time code the frontend got
  # from the API's callback into a session, for the browser whose nonce started
  # the sign-in. Google has verified who this is, so no emailed code follows.
  class RedeemGoogleSignIn < ApplicationService
    include SignInRestriction
    include GrantsAccess

    def initialize(code:, nonce:)
      @code = code
      @nonce = nonce
    end

    def call
      outcome = GoogleSignIn.take(:handoff, @code)
      refusal = refusal_for(outcome)
      return refusal if refusal

      user = User.find(outcome[:user_id])
      # Re-checked: access may have been revoked in the minute since the callback.
      return sign_in_blocked(user) unless user.can_sign_in?

      success(SignInOutcome.new(user:, session: start_session(user)))
    end

    private

    def refusal_for(outcome)
      return failure(:google_sign_in_failed, I18n.t("errors.google_sign_in_expired")) unless outcome
      return failure(outcome[:error], outcome[:message]) if outcome[:error]

      failure(:google_sign_in_failed) unless nonce_matches?(outcome[:nonce_digest])
    end

    def nonce_matches?(nonce_digest)
      ActiveSupport::SecurityUtils.secure_compare(nonce_digest, GoogleSignIn.digest(@nonce))
    end
  end
end

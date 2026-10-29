module Auth
  # First leg of Sign in with Google: where to send the browser. Normally
  # Google's account chooser; when Google sign-in can't start, straight back to
  # the frontend with the reason, which signInWithGoogle then reports.
  class StartGoogleSignIn < ApplicationService
    PKCE_VERIFIER_BYTES = 48

    def initialize(nonce:)
      @nonce = nonce
    end

    def call
      client = GoogleOauth::Client.new
      return back_to_frontend(:google_sign_in_disabled) unless client.configured?
      return back_to_frontend(:google_sign_in_failed) if @nonce.blank?

      verifier = SecureRandom.urlsafe_base64(PKCE_VERIFIER_BYTES)
      state = GoogleSignIn.store(:state, { nonce_digest: GoogleSignIn.digest(@nonce), code_verifier: verifier },
                                 expires_in: GoogleSignIn::STATE_TTL)
      success(client.authorize_url(state:, code_challenge: code_challenge(verifier)))
    end

    private

    def back_to_frontend(code) = success(GoogleSignIn.frontend_url(error: code, message: I18n.t("errors.#{code}")))

    def code_challenge(verifier) = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
  end
end

module Auth
  # Exchanges an emailed code for either a session (login) or a short-lived
  # password reset token (password reset), depending on why it was sent.
  class VerifySignInCode < ApplicationService
    include SignInRestriction
    include GrantsAccess
    include OneTimePasswords::Rejection

    Outcome = Data.define(:user, :session, :password_reset_token)

    def initialize(email:, code:, purpose:)
      @email = email
      @code = code
      @purpose = purpose
    end

    def call
      one_time_password = OneTimePassword.pending_for(@email, purpose: @purpose)
      return code_rejected(one_time_password) unless one_time_password&.correct_code?(@code)

      user = one_time_password.user
      return sign_in_blocked(user) unless user.can_sign_in?

      one_time_password.destroy!
      user.mark_email_verified!
      success(one_time_password.login? ? sign_in(user) : password_reset(user))
    end

    private

    def sign_in(user) = Outcome.new(user:, session: start_session(user), password_reset_token: nil)

    def password_reset(user)
      Outcome.new(user:, session: nil, password_reset_token: user.password_reset_token)
    end
  end
end

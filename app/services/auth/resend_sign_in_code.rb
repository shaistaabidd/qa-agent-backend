module Auth
  # Re-sends a login or password-reset code that is already in flight. It never
  # starts a new flow, so it cannot be used to bypass the password check.
  # A login resend says so when there is nothing to resend; a password-reset
  # resend stays silent, so it never reveals whether an account exists.
  class ResendSignInCode < ApplicationService
    def initialize(email:, purpose:)
      @email = email
      @purpose = purpose.to_s
    end

    def call
      one_time_password = OneTimePassword.pending_for(@email, purpose: @purpose)
      return no_code_pending unless one_time_password
      return failure(:rate_limited, I18n.t("errors.resend_cooldown")) unless one_time_password.resendable?

      OneTimePasswords::SendCode.call(user: one_time_password.user, purpose: one_time_password.purpose)
    end

    private

    def no_code_pending
      @purpose == "login" ? failure(:invalid_code, I18n.t("errors.login_code_not_pending")) : success
    end
  end
end

module EmailChanges
  # Re-sends the confirmation code to the pending new address. Always sends a
  # fresh code, or fails with the reason it can't.
  class ResendCode < ApplicationService
    def initialize(user:)
      @user = user
    end

    def call
      pending_code = @user.pending_email_confirmation
      return failure(:validation_failed, I18n.t("errors.no_email_change_pending")) unless pending_code
      return failure(:rate_limited, I18n.t("errors.resend_cooldown")) unless pending_code.resendable?

      OneTimePasswords::SendCode.call(user: @user, purpose: :email_confirmation, to: @user.unconfirmed_email)
      success(@user)
    end
  end
end

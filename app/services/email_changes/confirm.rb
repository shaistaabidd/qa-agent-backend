module EmailChanges
  # Final step: the code sent to the new address proves the user owns it.
  class Confirm < ApplicationService
    include OneTimePasswords::Rejection
    include NotifiesPreviousEmail

    def initialize(user:, code:)
      @user = user
      @code = code
    end

    def call
      return code_rejected(one_time_password) unless code_accepted?

      previous_email = @user.email
      return failure(:validation_failed, record: @user) unless apply_new_email

      notify_previous_email(previous_email)
      success(@user)
    end

    private

    def one_time_password = @one_time_password ||= @user.pending_email_confirmation

    def code_accepted? = one_time_password&.correct_code?(@code)

    def apply_new_email
      @user.assign_attributes(email: @user.unconfirmed_email, unconfirmed_email: nil, email_verified_at: Time.current)
      User.transaction { @user.save && one_time_password.destroy! }
    end
  end
end

module EmailChanges
  # Starts an email change. The current password proves it's the account
  # owner. With email_change_otp_enabled on, the new address must also be
  # confirmed with a code emailed to it (see Confirm) before the login email
  # changes; with it off, the login email changes immediately and the
  # previous address is only notified afterwards.
  class Request < ApplicationService
    include NotifiesPreviousEmail

    def initialize(user:, new_email:, current_password:)
      @user = user
      @new_email = User.normalize_value_for(:email, new_email)
      @current_password = current_password
    end

    def call
      unless @user.authenticate(@current_password)
        return failure(:invalid_credentials, I18n.t("errors.current_password_invalid"))
      end
      return failure(:validation_failed, I18n.t("errors.email_unchanged")) if @new_email == @user.email

      FeatureFlag.enabled?(:email_change_otp_enabled, @user) ? request_confirmation : change_immediately
    end

    private

    def request_confirmation
      @user.unconfirmed_email = @new_email
      return failure(:validation_failed, record: @user) unless @user.save

      OneTimePasswords::SendCode.call(user: @user, purpose: :email_confirmation, to: @user.unconfirmed_email)
      success(@user)
    end

    # A change started while codes were required is superseded: its pending
    # address and code must not be confirmable afterwards. Nobody proved the
    # new address, so it isn't verified.
    def change_immediately
      previous_email = @user.email
      @user.assign_attributes(email: @new_email, unconfirmed_email: nil, email_verified_at: nil)
      saved = User.transaction { @user.save && @user.one_time_passwords.email_confirmation.delete_all }
      return failure(:validation_failed, record: @user) unless saved

      notify_previous_email(previous_email)
      success(@user)
    end
  end
end

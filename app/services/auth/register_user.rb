module Auth
  # Public sign-up. Every self-registered account gets the `user` role and
  # confirms its email with an emailed code before a session is issued (see
  # ValidateOtp), whatever otp_enabled says: a new and an already-registered
  # address then get the same response, so sign-up never reveals which
  # addresses have accounts (the owner is emailed instead). sign_up_enabled is
  # checked for the role sign-up creates; off refuses every attempt outright.
  class RegisterUser < ApplicationService
    def initialize(email:, password:, password_confirmation:, first_name: nil, last_name: nil)
      @attributes = { email:, password:, password_confirmation:, first_name:, last_name: }
    end

    def call
      return failure(:sign_up_disabled) unless FeatureFlag.enabled?(:sign_up_enabled, FeatureFlag.visitor)

      user = User.new(**@attributes, role: User::SIGN_UP_ROLE)
      return create_account(user) if user.valid?

      email_taken = user.errors.delete(:email, :taken).present?
      return failure(:validation_failed, record: user) if user.errors.any?

      notify_existing_account(user.email) if email_taken
      success(SignInOutcome.new(user: nil, session: nil))
    end

    private

    def create_account(user)
      User.transaction do
        user.save!
        OneTimePasswords::SendCode.call(user:, purpose: :login)
      end
      success(SignInOutcome.new(user:, session: nil))
    rescue ActiveRecord::RecordNotUnique
      # Lost a race with a concurrent sign-up for the same address.
      notify_existing_account(user.email)
      success(SignInOutcome.new(user: nil, session: nil))
    end

    def notify_existing_account(email)
      UserMailer.with(user: User.find_by!(email:)).registration_attempted.deliver_later
    end
  end
end

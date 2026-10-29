module Auth
  # Always succeeds, so the response never reveals whether an account exists.
  class RequestPasswordReset < ApplicationService
    def initialize(email:)
      @email = email
    end

    def call
      user = User.find_by(email: @email)
      OneTimePasswords::SendCode.call(user:, purpose: :password_reset) if user&.can_sign_in?
      success
    end
  end
end

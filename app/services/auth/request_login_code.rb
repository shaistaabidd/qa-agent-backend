module Auth
  # First login step: checks the password. With otp_enabled on, emails a code
  # that VerifySignInCode exchanges for a session (see ValidateOtp); with it
  # off, signs the user in immediately instead.
  class RequestLoginCode < ApplicationService
    include SignInRestriction
    include GrantsAccess

    def initialize(email:, password:)
      @email = email
      @password = password
    end

    def call
      user = User.authenticate_by(email: @email, password: @password)
      return failure(:invalid_credentials) unless user
      return sign_in_blocked(user) unless user.can_sign_in?

      success(SignInOutcome.new(user:, session: grant_access(user)))
    end
  end
end

module Mutations
  module Auth
    class ValidateOtp < BaseMutation
      description <<~DESC.squish
        Exchanges an emailed code. A login code returns a session token and the user;
        a password reset code returns resetPasswordToken for setPassword instead.
      DESC

      allow_unauthenticated!
      rate_limit to: 10, within: 15.minutes, by: ->(arguments) { arguments[:email] }
      rate_limit to: 30, within: 15.minutes

      argument :email, String, description: "Email the code was sent to"
      argument :otp_code, String, validates: { format: { with: /\A\d{6}\z/ } }, description: "6-digit code"
      argument :purpose, Types::SignInPurposeEnum, description: "Which flow this code screen belongs to"

      field :token, String, description: "Bearer token for the Authorization header. Null for a password reset."
      field :user, Types::UserType, null: false, description: "The verified user"
      field :reset_password_token, String, description: "Pass to setPassword. Only set for a password reset."

      def resolve(email:, otp_code:, purpose:)
        outcome = value_or_raise!(::Auth::VerifySignInCode.call(email:, code: otp_code, purpose:))
        { token: outcome.session&.token, user: outcome.user, reset_password_token: outcome.password_reset_token }
      end
    end
  end
end

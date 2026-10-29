module Mutations
  module Auth
    class ResendOtp < BaseMutation
      description "Re-sends the login or password reset code currently in progress for this email"

      allow_unauthenticated!
      rate_limit to: 5, within: 15.minutes, by: ->(arguments) { arguments[:email] }
      rate_limit to: 15, within: 15.minutes

      argument :email, String, description: "Email the original code was sent to"
      argument :purpose, Types::SignInPurposeEnum, description: "Which flow this code screen belongs to"

      field :message, String, null: false, description: "Always the same, whether or not a code was sent"

      def resolve(email:, purpose:)
        value_or_raise!(::Auth::ResendSignInCode.call(email:, purpose:))
        { message: I18n.t("auth.verification_code_resent") }
      end
    end
  end
end

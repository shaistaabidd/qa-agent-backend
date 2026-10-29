module Mutations
  module Auth
    class SendResetPasswordInstructions < BaseMutation
      description "Emails a password reset code when the account exists. Continue with validateOtp."

      allow_unauthenticated!
      rate_limit to: 5, within: 1.hour, by: ->(arguments) { arguments[:email] }
      rate_limit to: 10, within: 1.hour

      argument :email, String, description: "Account email address"

      field :message, String, null: false,
                              description: "Always the same, so it never reveals whether the account exists"

      def resolve(email:)
        ::Auth::RequestPasswordReset.call(email:)
        { message: I18n.t("auth.password_reset_requested") }
      end
    end
  end
end

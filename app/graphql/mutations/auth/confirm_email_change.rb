module Mutations
  module Auth
    class ConfirmEmailChange < BaseMutation
      description "Confirms the new email address with the code sent to it and makes it the sign-in email"

      rate_limit to: 10, within: 15.minutes, by: ->(_arguments) { current_user.id }

      argument :otp_code, String, validates: { format: { with: /\A\d{6}\z/ } }, description: "6-digit code"

      field :user, Types::UserType, null: false, description: "The user with the new email"

      def resolve(otp_code:)
        authorize! current_user, to: :change_credentials?
        { user: value_or_raise!(::EmailChanges::Confirm.call(user: current_user, code: otp_code)) }
      end
    end
  end
end

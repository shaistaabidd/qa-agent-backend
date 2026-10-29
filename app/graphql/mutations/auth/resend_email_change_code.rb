module Mutations
  module Auth
    class ResendEmailChangeCode < BaseMutation
      description "Sends a fresh code to the pending new email address. Allowed 30 seconds after the previous one."

      rate_limit to: 5, within: 15.minutes, by: ->(_arguments) { current_user.id }

      field :message, String, null: false, description: "Confirmation that a new code was sent"

      def resolve
        authorize! current_user, to: :change_credentials?

        user = value_or_raise!(::EmailChanges::ResendCode.call(user: current_user))
        { message: I18n.t("auth.code_sent_to", email: user.unconfirmed_email) }
      end
    end
  end
end

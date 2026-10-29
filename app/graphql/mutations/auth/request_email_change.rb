module Mutations
  module Auth
    class RequestEmailChange < BaseMutation
      description <<~DESC.squish
        Starts an email change: checks the current password. With email_change_otp_enabled on, emails
        a 6-digit code to the new address - the login email changes only after confirmEmailChange. With
        it off, the login email changes immediately.
      DESC

      rate_limit to: 5, within: 15.minutes, by: ->(_arguments) { current_user.id }

      argument :email, String, description: "The new email address"
      argument :current_password, String, description: "Password in use today"

      field :user, Types::UserType, null: false, description: "The user, with the new address in unconfirmedEmail"
      field :message, String, null: false, description: "Confirmation that a code was sent"

      def resolve(email:, current_password:)
        authorize! current_user, to: :change_credentials?

        user = value_or_raise!(::EmailChanges::Request.call(user: current_user, new_email: email, current_password:))
        message = if user.unconfirmed_email
                    I18n.t("auth.code_sent_to", email: user.unconfirmed_email)
                  else
                    I18n.t("auth.email_changed")
                  end
        { user:, message: }
      end
    end
  end
end

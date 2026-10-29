module Queries
  module Auth
    class ValidateInvitationToken < BaseQuery
      description "Checks an invitation link before showing the set-password form"

      allow_unauthenticated!
      rate_limit to: 30, within: 15.minutes

      type Types::InvitationTokenValidationType, null: false

      argument :token, String, description: "Token from the invitation link"

      def resolve(token:)
        return { valid: true, error: nil } if User.find_by_invitation_token(token)

        { valid: false, error: I18n.t("errors.invalid_token") }
      end
    end
  end
end

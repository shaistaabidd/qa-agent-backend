module Mutations
  module Auth
    class AcceptInvitation < BaseMutation
      description "Sets the password for an invited account and starts a session"

      allow_unauthenticated!
      rate_limit to: 10, within: 15.minutes

      argument :set_password_attributes, Types::AcceptInvitationAttributesInput,
               description: "Password and invitation token"

      field :token, String, null: false, description: "Bearer token for the Authorization header"
      field :user, Types::UserType, null: false, description: "The signed-in user"

      def resolve(set_password_attributes:)
        session = value_or_raise!(::Auth::AcceptInvitation.call(**set_password_attributes.to_h))
        { token: session.token, user: session.user }
      end
    end
  end
end

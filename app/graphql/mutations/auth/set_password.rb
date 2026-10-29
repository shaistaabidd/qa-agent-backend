module Mutations
  module Auth
    class SetPassword < BaseMutation
      description "Sets a new password with the token from validateOtp, signs out every device and starts a new session"

      allow_unauthenticated!
      rate_limit to: 10, within: 15.minutes

      argument :set_password_attributes, Types::ResetPasswordAttributesInput, description: "New password and token"

      field :token, String, null: false, description: "Bearer token for the Authorization header"
      field :user, Types::UserType, null: false, description: "The signed-in user"

      def resolve(set_password_attributes:)
        session = value_or_raise!(::Auth::ResetPassword.call(**set_password_attributes.to_h))
        { token: session.token, user: session.user }
      end
    end
  end
end

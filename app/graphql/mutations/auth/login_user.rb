module Mutations
  module Auth
    class LoginUser < BaseMutation
      include SignInResponse

      description "Checks email and password. Signs in immediately if otp_enabled is off, else emails a login code."

      allow_unauthenticated!
      rate_limit to: 10, within: 15.minutes, by: ->(arguments) { arguments[:login_attributes][:email] }
      rate_limit to: 30, within: 15.minutes

      argument :login_attributes, Types::LoginAttributesInput, description: "Email and password"

      field :message, String, null: false, description: "Confirmation message"
      field :token, String, description: "Bearer token for the Authorization header. Set only when otp_enabled is off"
      field :user, Types::UserType, description: "The signed-in user. Set only when otp_enabled is off"

      def resolve(login_attributes:)
        sign_in_payload(value_or_raise!(::Auth::RequestLoginCode.call(**login_attributes.to_h)))
      end
    end
  end
end

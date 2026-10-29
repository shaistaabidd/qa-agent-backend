module Mutations
  module Auth
    class RegisterUser < BaseMutation
      include SignInResponse

      description "Creates a `user` account and emails a code to confirm the address (validateOtp then signs in). " \
                  "Answers the same for an address that already has an account."

      allow_unauthenticated!
      rate_limit to: 5, within: 1.hour

      argument :register_attributes, Types::RegisterAttributesInput, description: "New account details"

      field :message, String, null: false, description: "Confirmation message"
      field :token, String, description: "Always null",
                            deprecation_reason: "Sign-up confirms by code; validateOtp returns the token"
      field :user, Types::UserType, description: "Always null",
                                    deprecation_reason: "Sign-up confirms by code; validateOtp returns the user"

      def resolve(register_attributes:)
        sign_in_payload(value_or_raise!(::Auth::RegisterUser.call(**register_attributes.to_h)))
      end
    end
  end
end

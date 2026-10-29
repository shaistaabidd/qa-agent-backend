module Mutations
  module Auth
    class SignInWithGoogle < BaseMutation
      include SignInResponse

      description "Finishes Sign in with Google: exchanges the one-time code the API's Google callback put in " \
                  "the frontend URL for a session. No emailed code follows."

      allow_unauthenticated!
      rate_limit to: 10, within: 15.minutes

      argument :code, String, description: "The one-time code from the frontend callback URL's fragment"
      argument :nonce, String, description: "The nonce this browser sent to /auth/google when it started"

      field :message, String, null: false, description: "Confirmation message"
      field :token, String, null: false, description: "Bearer token for the Authorization header"
      field :user, Types::UserType, null: false, description: "The signed-in user"

      def resolve(code:, nonce:)
        sign_in_payload(value_or_raise!(::Auth::RedeemGoogleSignIn.call(code:, nonce:)))
      end
    end
  end
end

module Mutations
  module Users
    class UpdatePassword < BaseMutation
      description "Changes the signed-in user's password and signs out their other devices"

      rate_limit to: 5, within: 15.minutes, by: ->(_arguments) { current_user.id }

      argument :current_password, String, description: "Password in use today"
      argument :password, String, description: "8+ characters with upper, lower and special characters"
      argument :password_confirmation, String, description: "Must match password"

      field :success, Boolean, null: false, description: "True when the password was changed"

      def resolve(current_password:, password:, password_confirmation:)
        authorize! current_user, to: :change_credentials?

        value_or_raise!(::Users::ChangePassword.call(user: current_user, current_password:, password:,
                                                     password_confirmation:, current_session:))
        { success: true }
      end
    end
  end
end

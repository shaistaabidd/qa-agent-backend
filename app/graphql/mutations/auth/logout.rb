module Mutations
  module Auth
    class Logout < BaseMutation
      description "Ends the current session. The token stops working immediately."

      field :message, String, null: false, description: "Confirmation message"
      field :success, Boolean, null: false, description: "True when the session was ended"

      def resolve
        current_session.destroy!
        { message: I18n.t("auth.logged_out"), success: true }
      end
    end
  end
end

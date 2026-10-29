module Mutations
  module Auth
    class ImpersonateUser < BaseMutation
      description <<~DESC.squish
        Super admins only: starts a one-hour session as another user. Credentials stay locked. FORBIDDEN
        unless impersonation_enabled is on for that user or their role (never for a super admin).
      DESC

      argument :user_id, ID, description: "The user to act as"

      field :token, String, null: false, description: "Bearer token for the impersonated session"
      field :user, Types::UserType, null: false, description: "The impersonated user"

      def resolve(user_id:)
        user = authorized_scope(User.all).find(user_id)
        authorize! user, to: :impersonate?

        session = Session.start_for!(user, impersonator: current_user)
        { token: session.token, user: }
      end
    end
  end
end

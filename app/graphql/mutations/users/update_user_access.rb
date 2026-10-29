module Mutations
  module Users
    class UpdateUserAccess < BaseMutation
      description "Super admins only: revokes a user's access, which signs them out and blocks sign-in, or restores it"

      argument :id, ID, description: "User to update"
      argument :access_revoked, Boolean, description: "True to revoke access, false to restore it"

      field :user, Types::UserType, null: false, description: "The updated user"

      def resolve(id:, access_revoked:)
        user = authorized_scope(User.all).find(id)
        authorize! user, to: :update_access?

        access_revoked ? user.revoke_access! : user.restore_access!
        { user: }
      end
    end
  end
end

module Mutations
  module Users
    class ArchiveUser < BaseMutation
      description "Super admins only: archives a user, which signs them out and blocks sign-in, or restores them"

      argument :id, ID, description: "User to archive or restore"
      argument :archived, Boolean, description: "True to archive, false to restore"

      field :user, Types::UserType, null: false, description: "The updated user"

      def resolve(id:, archived:)
        user = authorized_scope(User.all).find(id)
        authorize! user, to: :archive?

        archived ? user.archive! : user.unarchive!
        { user: }
      end
    end
  end
end

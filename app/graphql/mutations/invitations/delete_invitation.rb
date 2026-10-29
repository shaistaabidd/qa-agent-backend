module Mutations
  module Invitations
    class DeleteInvitation < BaseMutation
      description "Super admins only: cancels a pending invitation and removes the invited account"

      argument :id, ID, description: "Invited user"

      field :message, String, null: false, description: "Confirmation message"

      def resolve(id:)
        user = authorized_scope(User.all).find(id)
        authorize! user, to: :destroy_invitation?

        user.destroy!
        { message: I18n.t("invitations.deleted") }
      end
    end
  end
end

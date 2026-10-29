module Mutations
  module Invitations
    class ResendInvitation < BaseMutation
      description "Super admins only: sends a fresh invitation link. Earlier links stop working."

      argument :id, ID, description: "Invited user"

      field :user, Types::UserType, null: false, description: "The invited user"

      def resolve(id:)
        user = authorized_scope(User.all).find(id)
        authorize! user, to: :resend_invitation?

        { user: value_or_raise!(::Invitations::ResendInvitation.call(user:)) }
      end
    end
  end
end

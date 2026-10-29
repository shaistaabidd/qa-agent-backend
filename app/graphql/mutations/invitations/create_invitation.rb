module Mutations
  module Invitations
    class CreateInvitation < BaseMutation
      description "Super admins only: invites up to 20 people. Invalid addresses are skipped and listed in rejected."

      argument :emails, [String], description: "Addresses to invite"
      argument :role, Types::UserRoleEnum, description: "Role the invited users will have"

      field :message, String, null: false, description: "Confirmation message"
      field :users, [Types::UserType], null: false, description: "The invited users"
      field :rejected, [Types::InvitationRejectionType], null: false,
                                                         description: "Addresses that were skipped, with the reason"

      def resolve(emails:, role:)
        authorize! User.new(role:), to: :invite?

        outcome = value_or_raise!(::Invitations::SendInvitations.call(emails:, role:, invited_by: current_user))
        { message: I18n.t("invitations.sent", count: outcome.invited.size), users: outcome.invited,
          rejected: outcome.rejected }
      end
    end
  end
end

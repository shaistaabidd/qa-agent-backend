module Mutations
  module Users
    class UpdateUser < BaseMutation
      description "Updates a profile. Omit id for your own account; super admins may pass another user's id."

      argument :id, ID, required: false, description: "User to update. Defaults to the signed-in user."
      argument :user_attributes, Types::UserAttributesInput, description: "Fields to change"

      field :user, Types::UserType, null: false, description: "The updated user"

      def resolve(user_attributes:, id: nil)
        user = id ? authorized_scope(User.all).find(id) : current_user
        authorize! user, to: :update?

        { user: value_or_raise!(::Users::UpdateProfile.call(user:, attributes: user_attributes.to_h)) }
      end
    end
  end
end

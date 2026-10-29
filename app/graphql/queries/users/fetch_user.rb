module Queries
  module Users
    class FetchUser < BaseQuery
      description "Returns a user. Omit id for the signed-in user; super admins may fetch anyone."

      type Types::UserType, null: false

      argument :id, ID, required: false, description: "User to fetch. Defaults to the signed-in user."

      def resolve(id: nil)
        user = id ? authorized_scope(User.all).find(id) : current_user
        authorize! user, to: :show?
        user
      end
    end
  end
end

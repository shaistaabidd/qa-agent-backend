module Queries
  module Users
    class Me < Queries::BaseQuery
      include AuthenticableApiUser

      type Types::Users::UserType, null: false

      def resolve
        authenticate_user!
        current_user
      rescue GraphQL::ExecutionError
        raise
      rescue StandardError => e
        execution_error(message: e.message)
      end
    end
  end
end

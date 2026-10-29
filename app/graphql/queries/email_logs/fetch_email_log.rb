module Queries
  module EmailLogs
    class FetchEmailLog < BaseQuery
      description "Super admins only: one sent email"

      type Types::EmailLogType, null: false

      argument :id, ID, description: "Email log to fetch"

      def resolve(id:)
        authorize! EmailLog, to: :show?
        authorized_scope(EmailLog.all).find(id)
      end
    end
  end
end

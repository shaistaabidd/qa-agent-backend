module Queries
  module SmsLogs
    class FetchSmsLog < BaseQuery
      description "Super admins only: one sent SMS"

      type Types::SmsLogType, null: false

      argument :id, ID, description: "SMS log to fetch"

      def resolve(id:)
        authorize! SmsLog, to: :show?
        authorized_scope(SmsLog.all).find(id)
      end
    end
  end
end

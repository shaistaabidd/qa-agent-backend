module Queries
  module SmsLogs
    class AllSmsLogs < BaseQuery
      include Paginatable

      description "Super admins only: a filtered, paginated list of sent SMS, newest first"

      type Types::SmsLogPaginationType, null: false

      argument :filter, Types::SmsLogFilterInput, required: false, description: "Filters and paging"

      extras [:lookahead]

      def resolve(lookahead:, filter: nil)
        authorize! SmsLog, to: :index?

        options = filter.to_h
        sms_logs = ::SmsLogs::FilterQuery.new(authorized_scope(SmsLog.all)).call(**filters_without_paging(options))
        sms_logs = sms_logs.includes(:user) if lookahead.selection(:all_data).selects?(:user)
        paginate_with_filter(sms_logs, options)
      end
    end
  end
end

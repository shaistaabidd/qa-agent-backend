module Queries
  module EmailLogs
    class AllEmailLogs < BaseQuery
      include Paginatable

      description "Super admins only: a filtered, paginated list of sent emails, newest first"

      type Types::EmailLogPaginationType, null: false

      argument :filter, Types::EmailLogFilterInput, required: false, description: "Filters and paging"

      extras [:lookahead]

      def resolve(lookahead:, filter: nil)
        authorize! EmailLog, to: :index?

        options = filter.to_h
        email_logs = ::EmailLogs::FilterQuery.new(authorized_scope(EmailLog.all)).call(**filters_without_paging(options))
        email_logs = email_logs.without_body unless lookahead.selection(:all_data).selects?(:body)
        paginate_with_filter(email_logs, options)
      end
    end
  end
end

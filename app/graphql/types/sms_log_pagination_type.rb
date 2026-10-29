module Types
  class SmsLogPaginationType < BasePaginationType
    description "One page of SMS logs"

    field :all_data, [SmsLogType], null: false, method: :records, description: "SMS logs on this page"
  end
end

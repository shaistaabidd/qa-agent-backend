module Types
  class EmailLogPaginationType < BasePaginationType
    description "One page of email logs"

    field :all_data, [EmailLogType], null: false, method: :records, description: "Email logs on this page"
  end
end

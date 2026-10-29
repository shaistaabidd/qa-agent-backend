module Types
  class UserPaginationType < BasePaginationType
    description "One page of users"

    field :all_data, [UserType], null: false, method: :records, description: "Users on this page"
  end
end

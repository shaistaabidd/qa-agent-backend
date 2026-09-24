module Types
  module Runs
    class RunsPagination < Types::Shared::CorePaginatedType
      field :all_data, [Types::Runs::RunType], null: false
    end
  end
end

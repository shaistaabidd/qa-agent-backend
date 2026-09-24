module Types
  module Findings
    class FindingsPagination < Types::Shared::CorePaginatedType
      field :all_data, [Types::Findings::FindingType], null: false
    end
  end
end

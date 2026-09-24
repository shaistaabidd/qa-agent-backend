module Types
  module Shared
    class CorePaginatedType < Types::BaseObject
      field :total_pages, Integer, null: true
      field :prev_page, Integer, null: true
      field :next_page, Integer, null: true
    end
  end
end

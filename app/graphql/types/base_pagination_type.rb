module Types
  # Offset page metadata. Subclasses add `all_data` with their record type.
  class BasePaginationType < BaseObject
    field :count, Integer, null: false, description: "Total number of matching records"
    field :current_page, Integer, null: false, method: :page, description: "The page returned"
    field :total_pages, Integer, null: false, method: :last, description: "Number of pages"
    field :next_page, Integer, method: :next, description: "Next page number, null on the last page"
    field :prev_page, Integer, method: :previous, description: "Previous page number, null on the first page"
  end
end

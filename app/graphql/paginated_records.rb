PaginatedRecords = Data.define(:records, :pagy) do
  delegate :count, :page, :last, :next, :previous, to: :pagy
end

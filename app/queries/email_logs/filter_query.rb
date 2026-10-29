module EmailLogs
  # Narrows an already-authorized email log scope by the admin list filters.
  class FilterQuery
    include ListFilters

    def initialize(scope)
      @scope = scope
    end

    def call(search: nil, status: nil, start_date: nil, end_date: nil)
      relation = @scope.order(created_at: :desc, id: :desc)
      relation = relation.where(status:) if status
      relation = filter_by_dates(relation, start_date, end_date)
      filter_by_search(relation, search)
    end
  end
end

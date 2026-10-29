# Filters shared by the admin list query objects (users, email logs, SMS logs).
# Each list's table has a stored, trigram-indexed `search_document` column.
module ListFilters
  private

  # Dates are whole days in the app time zone, inclusive at both ends.
  def filter_by_dates(relation, start_date, end_date)
    return relation unless start_date || end_date

    relation.where(created_at: start_date&.beginning_of_day..end_date&.end_of_day)
  end

  # Case-insensitive substring match (ILIKE); % and _ in the term match literally.
  def filter_by_search(relation, search)
    term = search.to_s.strip
    return relation if term.empty?

    pattern = "%#{relation.klass.sanitize_sql_like(term)}%"
    relation.where(relation.arel_table[:search_document].matches(pattern))
  end
end

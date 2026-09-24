module Pagination
  extend ActiveSupport::Concern

  def paginate(relation, page:, per_page:)
    relation.page(page).per(per_page)
  end

  def pagination_response(objects)
    {
      all_data: objects,
      total_pages: objects.total_pages || 0,
      next_page: objects.next_page || 0,
      prev_page: objects.prev_page || 0
    }
  end
end

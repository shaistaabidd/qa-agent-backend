module Paginatable
  extend ActiveSupport::Concern

  include Pagy::Method

  PAGING_ARGUMENTS = %i[page per_page].freeze

  private

  # A list filter input's own filters, without its paging arguments.
  def filters_without_paging(options) = options.except(*PAGING_ARGUMENTS)

  # Paginates with a list filter input's page and per_page (the defaults when no
  # filter was given). Pagy clamps the page size to Pagy::OPTIONS[:client_limit].
  def paginate_with_filter(scope, options)
    params = { "page" => options.fetch(:page, 1), "limit" => options.fetch(:per_page, Pagy::OPTIONS[:limit]) }
    pagy, records = pagy(:offset, scope, request: { params: })
    PaginatedRecords.new(records:, pagy:)
  end
end

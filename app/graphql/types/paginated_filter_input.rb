module Types
  class PaginatedFilterInput < BaseInputObject
    description "Paging arguments shared by every list filter"

    argument :page, Integer, required: false, default_value: 1, validates: { numericality: { greater_than: 0 } },
                             description: "Page number, starting at 1"
    argument :per_page, Integer, required: false, default_value: Pagy::OPTIONS[:limit],
                                 validates: { numericality: { greater_than: 0 } },
                                 description: "Page size, capped at #{Pagy::OPTIONS[:client_limit]}"
  end
end

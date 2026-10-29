module Types
  class EmailLogFilterInput < PaginatedFilterInput
    description "Filters and paging for the email log list"

    argument :search, String, required: false, description: "Matches recipient or subject"
    argument :status, EmailLogStatusEnum, required: false, description: "Only attempts with this outcome"
    argument :start_date, GraphQL::Types::ISO8601Date, required: false,
                                                       description: "Attempts on or after this day (YYYY-MM-DD)"
    argument :end_date, GraphQL::Types::ISO8601Date, required: false,
                                                     description: "Attempts on or before this day (YYYY-MM-DD)"
  end
end

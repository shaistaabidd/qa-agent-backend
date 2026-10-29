module Types
  class RunFilterInput < PaginatedFilterInput
    description "Filters and paging for a project's runs"

    argument :status, RunStatusEnum, required: false, description: "Only runs in this status"
  end
end

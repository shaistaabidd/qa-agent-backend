module Types
  class FindingFilterInput < PaginatedFilterInput
    description "Filters and paging for a project's findings"

    argument :grouped, Boolean, required: false, default_value: true,
                                description: "One row per issue (its latest occurrence) instead of every finding"
    argument :run_id, ID, required: false, description: "Only findings from this run"
    argument :severity, FindingSeverityEnum, required: false, description: "Only findings this serious"
    argument :category, String, required: false, description: "Only findings in this category"
    argument :source, FindingSourceEnum, required: false, description: "Only findings from this source"
  end
end

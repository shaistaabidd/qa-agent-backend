module Queries
  module Findings
    class AllFindings < BaseQuery
      include Paginatable
      include ProjectAccess

      description "A project's findings, newest first. Grouped by default: one row per issue, with its stats."

      type Types::FindingPaginationType, null: false

      argument :project_id, ID, description: "Project whose findings to list"
      argument :filter, Types::FindingFilterInput, required: false, description: "Filters and paging"

      extras [:lookahead]

      def resolve(lookahead:, project_id:, filter: nil)
        project = find_project(project_id)
        options = filter.to_h
        screenshots = lookahead.selection(:all_data).selects?(:screenshot_url)

        context[:issue_stats] = ::Findings::IssueStats.new(project).call
        findings = ::Findings::FilterQuery.new(project).call(**options.except(*Paginatable::PAGING_ARGUMENTS))
        # Only worth preloading when the list shows the screenshot URLs.
        findings = findings.with_attached_screenshot if screenshots
        paginate_with_filter(findings, options)
      end
    end
  end
end

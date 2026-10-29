module Queries
  module Findings
    class FetchFindingsSummary < BaseQuery
      include ProjectAccess

      description "Open and resolved issue counts for a project"

      type Types::FindingsSummaryType, null: false

      argument :project_id, ID, description: "Project to summarize"

      def resolve(project_id:) = ::Findings::Summary.new(find_project(project_id)).call
    end
  end
end

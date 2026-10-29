module Queries
  module Findings
    class FetchFinding < BaseQuery
      include ProjectAccess

      description "One finding in a project the user can see, with its issue's history across runs"

      type Types::FindingType, null: false

      argument :id, ID, description: "Finding to fetch"

      def resolve(id:)
        finding = Finding.joins(:run).where(runs: { project_id: authorized_scope(Project.all).select(:id) }).find(id)
        project = finding.run.project
        authorize!(project, to: :show?)

        context[:issue_stats] = ::Findings::IssueStats.new(project).call
        finding
      end
    end
  end
end

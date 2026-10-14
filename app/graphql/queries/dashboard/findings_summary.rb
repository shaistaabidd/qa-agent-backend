module Queries
  module Dashboard
    class FindingsSummary < Queries::BaseQuery
      include AuthenticableApiUser
      include PermissionHandler

      argument :project_id, ID, required: true

      type Types::Dashboard::FindingsSummaryType, null: false

      def resolve(**params)
        authenticate_user!
        project = Project.find(params[:project_id])
        authenticate_project_access!(project)

        summary_for(project)
      rescue GraphQL::ExecutionError
        raise
      rescue ActiveRecord::RecordNotFound
        execution_error(message: 'Project not found', code: 404)
      rescue StandardError => e
        execution_error(message: e.message)
      end

      private

      # Counts *open issues* — one per fingerprint, latest occurrence, not
      # resolved — so the numbers match the Issues tab instead of adding up
      # every finding from every run.
      def summary_for(project)
        stats = ::Queries::Findings::IssueStats.new(project).call
        findings = ::Finding.joins(:run).where(runs: { project_id: project.id })
        issues = latest_per_issue(findings)
        open_issues = issues.reject { |issue| stats.dig(issue.fingerprint || issue.title, :status) == 'resolved' }
        counts_by_severity = open_issues.group_by(&:severity).transform_values(&:size)

        {
          total: open_issues.size,
          resolved: issues.size - open_issues.size,
          total_findings: findings.count,
          by_severity: ::Finding.severities.keys.map do |severity|
            { severity: severity, count: counts_by_severity[severity] || 0 }
          end,
          posted_to_click_up: open_issues.count(&:clickup_task_id),
          pending_click_up: open_issues.count { |issue| issue.clickup_task_id.nil? }
        }
      end

      def latest_per_issue(findings)
        key = ::Queries::Findings::IssueStats::KEY
        ::Finding.where(id: findings.select("DISTINCT ON (#{key}) findings.id").reorder(Arel.sql("#{key}, findings.created_at DESC")))
                 .to_a
      end
    end
  end
end

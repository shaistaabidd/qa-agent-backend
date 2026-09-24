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

      def summary_for(project)
        findings = ::Finding.joins(:run).where(runs: { project_id: project.id })
        counts_by_severity = findings.group(:severity).count

        {
          total: findings.count,
          by_severity: ::Finding.severities.keys.map do |severity|
            { severity: severity, count: counts_by_severity[severity] || 0 }
          end,
          posted_to_click_up: findings.where.not(clickup_task_id: nil).count,
          pending_click_up: findings.where(clickup_task_id: nil).count
        }
      end
    end
  end
end

module Queries
  module Findings
    class ForProject < Queries::BaseQuery
      include AuthenticableApiUser
      include PermissionHandler
      include Pagination

      argument :project_id, ID, required: true
      argument :page, Integer, required: false, default_value: 1
      argument :per_page, Integer, required: false, default_value: 20
      argument :grouped, Boolean, required: false, default_value: true,
                                  description: 'One row per issue (latest occurrence) instead of every finding'
      argument :run_id, ID, required: false
      argument :severity, Types::Enums::FindingSeverityEnum, required: false
      argument :category, String, required: false
      argument :source, String, required: false, description: 'frontend | backend | network'

      type Types::Findings::FindingsPagination, null: false

      def resolve(**params)
        authenticate_user!
        project = Project.find(params[:project_id])
        authenticate_project_access!(project)

        context[:issue_stats] = IssueStats.new(project).call
        # Each row renders screenshot_url; preload attachments + blobs in two
        # queries instead of two per finding (N+1).
        findings = filter(scope_for(project, params), params).with_attached_screenshot.order(created_at: :desc)
        pagination_response(paginate(findings, page: params[:page], per_page: params[:per_page]))
      rescue GraphQL::ExecutionError
        raise
      rescue ActiveRecord::RecordNotFound
        execution_error(message: 'Project not found', code: 404)
      rescue StandardError => e
        execution_error(message: e.message)
      end

      private

      def scope_for(project, params)
        scope = ::Finding.joins(:run).where(runs: { project_id: project.id })
        scope = scope.where(run_id: params[:run_id]) if params[:run_id]
        return scope unless params[:grouped] && params[:run_id].blank?

        latest_ids = scope.select("DISTINCT ON (#{IssueStats::KEY}) findings.id")
                          .reorder(Arel.sql("#{IssueStats::KEY}, findings.created_at DESC"))
        ::Finding.where(id: latest_ids)
      end

      def filter(scope, params)
        scope = scope.where(severity: params[:severity]) if params[:severity]
        scope = scope.where(category: params[:category]) if params[:category].present?
        scope = scope.from_source(params[:source]) if ::Finding::SOURCES.include?(params[:source])
        scope
      end
    end
  end
end

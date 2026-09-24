module Queries
  module Dashboard
    # "Tested" means the approved scope feature has at least one Run — not
    # necessarily a completed/passing one. Coverage is measured against
    # approved features specifically, since unapproved ones aren't in scope
    # for testing yet.
    class Coverage < Queries::BaseQuery
      include AuthenticableApiUser
      include PermissionHandler

      argument :project_id, ID, required: true

      type Types::Dashboard::CoverageType, null: false

      def resolve(**params)
        authenticate_user!
        project = Project.find(params[:project_id])
        authenticate_project_access!(project)

        coverage_for(project)
      rescue GraphQL::ExecutionError
        raise
      rescue ActiveRecord::RecordNotFound
        execution_error(message: 'Project not found', code: 404)
      rescue StandardError => e
        execution_error(message: e.message)
      end

      private

      def coverage_for(project)
        approved = project.scope_features.where(approved: true)
        approved_count = approved.count
        tested_count = approved.joins(:runs).distinct.count

        {
          total_scope_features: project.scope_features.count,
          approved_scope_features: approved_count,
          tested_scope_features: tested_count,
          coverage_percentage: percentage(tested_count, approved_count)
        }
      end

      def percentage(numerator, denominator)
        return 0.0 unless denominator.positive?

        (numerator.to_f / denominator * 100).round(1)
      end
    end
  end
end

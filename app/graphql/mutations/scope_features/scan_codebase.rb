module Mutations
  module ScopeFeatures
    class ScanCodebase < BaseMutation
      include AuthenticableApiUser
      include PermissionHandler

      argument :project_id, ID, required: true

      type Types::Shared::StatusPayload

      def resolve(**params)
        authenticate_user!
        project = Project.find(params[:project_id])
        authenticate_project_admin!(project)
        raise repo_not_connected_error unless project.repo_connection

        RepoScanJob.perform_later(project.id)
        { success: true, message: 'Scan enqueued' }
      rescue GraphQL::ExecutionError
        raise
      rescue ActiveRecord::RecordNotFound
        execution_error(message: 'Project not found', code: 404)
      rescue StandardError => e
        execution_error(message: e.message)
      end

      private

      def repo_not_connected_error
        execution_error(message: 'Connect a GitHub repository before scanning', code: 422)
      end
    end
  end
end

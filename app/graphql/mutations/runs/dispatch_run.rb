module Mutations
  module Runs
    class DispatchRun < BaseMutation
      include AuthenticableApiUser
      include PermissionHandler

      argument :scope_feature_id, ID, required: true
      argument :role_name, String, required: true

      type Types::Runs::RunPayload

      def resolve(**params)
        authenticate_user!
        scope_feature = ScopeFeature.find(params[:scope_feature_id])
        authenticate_project_admin!(scope_feature.project)

        result = ::Runs::Dispatch.call(scope_feature: scope_feature, role_name: params[:role_name])
        result.success? ? result : execution_error(message: result.error)
      rescue GraphQL::ExecutionError
        raise
      rescue ActiveRecord::RecordNotFound
        execution_error(message: 'Scope feature not found', code: 404)
      rescue StandardError => e
        execution_error(message: e.message)
      end
    end
  end
end

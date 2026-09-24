module Mutations
  module ScopeFeatures
    class ApproveScopeFeature < BaseMutation
      include AuthenticableApiUser
      include PermissionHandler

      argument :id, ID, required: true

      type Types::ScopeFeatures::ScopeFeaturePayload

      def resolve(**params)
        authenticate_user!
        scope_feature = ScopeFeature.find(params[:id])
        authenticate_project_admin!(scope_feature.project)

        result = ::ScopeFeatures::Approve.call(scope_feature: scope_feature)
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

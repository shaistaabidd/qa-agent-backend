module Queries
  module ScopeFeatures
    class ForProject < Queries::BaseQuery
      include AuthenticableApiUser
      include PermissionHandler
      include Pagination

      argument :project_id, ID, required: true
      argument :page, Integer, required: false, default_value: 1
      argument :per_page, Integer, required: false, default_value: 20

      type Types::ScopeFeatures::ScopeFeaturesPagination, null: false

      def resolve(**params)
        authenticate_user!
        project = Project.find(params[:project_id])
        authenticate_project_access!(project)

        features = project.scope_features.order(created_at: :desc)
        pagination_response(paginate(features, page: params[:page], per_page: params[:per_page]))
      rescue GraphQL::ExecutionError
        raise
      rescue ActiveRecord::RecordNotFound
        execution_error(message: 'Project not found', code: 404)
      rescue StandardError => e
        execution_error(message: e.message)
      end
    end
  end
end

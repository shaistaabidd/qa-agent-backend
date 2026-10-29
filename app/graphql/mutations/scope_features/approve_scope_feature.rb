module Mutations
  module ScopeFeatures
    class ApproveScopeFeature < BaseMutation
      include ProjectAccess

      description "Project admins: approves a scope feature so runs may target it"

      argument :id, ID, description: "Scope feature to approve"

      field :scope_feature, Types::ScopeFeatureType, null: false, description: "The approved feature"

      def resolve(id:)
        scope_feature = find_in_projects(ScopeFeature, id)
        authorize! scope_feature.project, to: :manage?

        { scope_feature: value_or_raise!(::ScopeFeatures::Approve.call(scope_feature:)) }
      end
    end
  end
end

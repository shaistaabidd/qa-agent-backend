module Mutations
  module Runs
    class DispatchRun < BaseMutation
      include ProjectAccess

      description "Project admins: queues a run of an approved scope feature as one of the project's roles"

      rate_limit to: 30, within: 10.minutes, by: ->(_) { current_user.id }

      argument :scope_feature_id, ID, description: "Approved scope feature to run"
      argument :role_name, String, description: "Role to sign in as; it needs a stored credential"

      field :run, Types::RunType, null: false, description: "The queued run"

      def resolve(scope_feature_id:, role_name:)
        scope_feature = find_in_projects(ScopeFeature, scope_feature_id)
        authorize! scope_feature.project, to: :manage?

        { run: value_or_raise!(::Runs::Dispatch.call(scope_feature:, role_name:)) }
      end
    end
  end
end

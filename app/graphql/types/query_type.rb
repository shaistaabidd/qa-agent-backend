# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    field :node, Types::NodeType, null: true, description: 'Fetches an object given its ID.' do
      argument :id, ID, required: true, description: 'ID of the object.'
    end

    def node(id:)
      context.schema.object_from_id(id, context)
    end

    field :nodes, [Types::NodeType, { null: true }], null: true,
                                                     description: 'Fetches a list of objects given a list of IDs.' do
      argument :ids, [ID], required: true, description: 'IDs of the objects.'
    end

    def nodes(ids:)
      ids.map { |id| context.schema.object_from_id(id, context) }
    end

    # Add root-level fields here.
    # They will be entry points for queries on your schema.

    field :me, resolver: Queries::Users::Me
    field :my_projects, resolver: Queries::Projects::MyProjects
    field :fetch_project, resolver: Queries::Projects::FetchProject
    field :scope_features_for_project, resolver: Queries::ScopeFeatures::ForProject
    field :runs_for_project, resolver: Queries::Runs::ForProject
    field :fetch_run, resolver: Queries::Runs::FetchRun
    field :resolve_role_credential, resolver: Queries::Runs::ResolveRoleCredential
    field :findings_for_project, resolver: Queries::Findings::ForProject
    field :findings_summary, resolver: Queries::Dashboard::FindingsSummary
    field :coverage, resolver: Queries::Dashboard::Coverage
    field :role_credentials_for_project, resolver: Queries::RoleCredentials::ForProject
  end
end

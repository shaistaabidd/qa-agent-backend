module Types
  class RunType < BaseObject
    description "One exploratory run of a scope feature as one role"

    field :id, ID, null: false, description: "Unique identifier"
    field :role_name, String, null: false, description: "The role the worker signed in as"
    field :status, RunStatusEnum, null: false, description: "Where the run is in its lifecycle"
    field :started_at, GraphQL::Types::ISO8601DateTime, description: "When the worker was handed the run"
    field :finished_at, GraphQL::Types::ISO8601DateTime, description: "When the run reached an end state"
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: "When the run was queued"
    field :scope_feature, ScopeFeatureType, null: false, description: "The feature the run targeted"
    field :audit_log_entries, [AuditLogEntryType], null: false, description: "What the worker did, in order"
    field :network_log, GraphQL::Types::JSON, null: false, description: "Requests the worker observed"
    field :summary, GraphQL::Types::JSON, null: false, description: "The worker's summary of the run"
  end
end

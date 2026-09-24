module Types
  module Runs
    class RunType < Types::BaseObject
      field :id, ID, null: false
      field :role_name, String, null: false
      field :status, Types::Enums::RunStatusEnum, null: false
      field :started_at, GraphQL::Types::ISO8601DateTime, null: true
      field :finished_at, GraphQL::Types::ISO8601DateTime, null: true
      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :scope_feature, Types::ScopeFeatures::ScopeFeatureType, null: false
      field :audit_log_entries, [Types::Runs::AuditLogEntryType], null: false
    end
  end
end

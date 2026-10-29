module Types
  class AuditLogEntryType < BaseObject
    description "One thing the worker did during a run"

    field :id, ID, null: false, description: "Unique identifier"
    field :action_taken, String, null: false, description: "What the worker did, for example a click"
    field :target_element, String, description: "The element it acted on"
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: "When it was recorded"
  end
end

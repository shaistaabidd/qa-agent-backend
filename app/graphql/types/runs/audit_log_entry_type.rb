module Types
  module Runs
    class AuditLogEntryType < Types::BaseObject
      field :id, ID, null: false
      field :action_taken, String, null: false
      field :target_element, String, null: true
      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    end
  end
end

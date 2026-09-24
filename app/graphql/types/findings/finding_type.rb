module Types
  module Findings
    class FindingType < Types::BaseObject
      field :id, ID, null: false
      field :title, String, null: false
      field :repro_steps, [String], null: false
      field :severity, Types::Enums::FindingSeverityEnum, null: false
      field :screenshot_url, String, null: true
      field :clickup_task_id, String, null: true
      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    end
  end
end

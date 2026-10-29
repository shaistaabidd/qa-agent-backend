module Types
  class FindingType < BaseObject
    description "An issue the worker found during a run"

    field :id, ID, null: false, description: "Unique identifier"
    field :run_id, ID, null: false, description: "The run that found it"
    field :title, String, null: false, description: "Short summary"
    field :repro_steps, [String], null: false, description: "How to reproduce it"
    field :severity, FindingSeverityEnum, null: false, description: "How serious it is"
    field :category, String, description: "The worker's category for it"
    field :source, FindingSourceEnum, null: false, description: "Where the problem lives"
    field :details, GraphQL::Types::JSON, null: false, description: "Evidence the worker recorded"
    field :fingerprint, String, description: "Findings sharing a fingerprint are the same issue across runs"
    field :screenshot_url, String, description: "Signed screenshot URL, valid for one hour"
    field :clickup_task_id, String, description: "The ClickUp task it was posted to, once posted"
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: "When it was found"
    field :times_seen, Integer, description: "Runs it appeared in (issue listing only)"
    field :first_seen_at, GraphQL::Types::ISO8601DateTime, description: "First occurrence (issue listing only)"
    field :last_seen_at, GraphQL::Types::ISO8601DateTime, description: "Latest occurrence (issue listing only)"
    field :issue_status, String,
          description: "new, ongoing, regressed (came back after a run without it) or resolved (issue listing only)"

    def times_seen = issue_stats&.fetch(:times_seen)
    def first_seen_at = issue_stats&.fetch(:first_seen_at)
    def last_seen_at = issue_stats&.fetch(:last_seen_at)
    def issue_status = issue_stats&.fetch(:status)

    private

    def issue_stats = context[:issue_stats]&.dig(object.fingerprint || object.title)
  end
end

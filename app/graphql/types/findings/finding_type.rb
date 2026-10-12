module Types
  module Findings
    class FindingType < Types::BaseObject
      field :id, ID, null: false
      field :title, String, null: false
      field :repro_steps, [String], null: false
      field :severity, Types::Enums::FindingSeverityEnum, null: false
      field :screenshot_url, String, null: true
      field :category, String, null: true
      field :source, String, null: false, description: 'frontend | backend | network'
      field :details, GraphQL::Types::JSON, null: false
      field :fingerprint, String, null: true
      field :run_id, ID, null: false
      # Issue-level stats across all runs of the project (grouped listing only).
      field :times_seen, Integer, null: true
      field :first_seen_at, GraphQL::Types::ISO8601DateTime, null: true
      field :last_seen_at, GraphQL::Types::ISO8601DateTime, null: true
      field :issue_status, String, null: true,
                           description: 'new | ongoing | regressed (came back after a run without it) | resolved'

      def times_seen = issue_stats&.dig(:times_seen)
      def first_seen_at = issue_stats&.dig(:first_seen_at)
      def last_seen_at = issue_stats&.dig(:last_seen_at)
      def issue_status = issue_stats&.dig(:status)

      private

      def issue_stats
        context[:issue_stats]&.dig(object.fingerprint || object.title)
      end
      field :clickup_task_id, String, null: true
      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    end
  end
end

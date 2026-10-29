module Types
  class FindingsSummaryType < BaseObject
    description "Open and resolved issue counts for a project"

    field :total, Integer, null: false, description: "Open (unresolved) issues"
    field :resolved, Integer, null: false, description: "Issues not seen in the latest run"
    field :total_findings, Integer, null: false, description: "Raw findings across all runs"
    field :by_severity, [SeverityCountType], null: false, description: "Open issues per severity"
    field :posted_to_click_up, Integer, null: false, description: "Open issues already posted to ClickUp"
    field :pending_click_up, Integer, null: false, description: "Open issues not yet posted"
  end
end

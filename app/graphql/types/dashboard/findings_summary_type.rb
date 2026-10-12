module Types
  module Dashboard
    class FindingsSummaryType < Types::BaseObject
      field :total, Integer, null: false, description: 'Open (unresolved) issues'
      field :resolved, Integer, null: false, description: 'Issues not seen in the latest run'
      field :total_findings, Integer, null: false, description: 'Raw findings across all runs'
      field :by_severity, [Types::Dashboard::SeverityCountType], null: false
      field :posted_to_click_up, Integer, null: false
      field :pending_click_up, Integer, null: false
    end
  end
end

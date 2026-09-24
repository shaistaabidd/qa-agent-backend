module Types
  module Dashboard
    class FindingsSummaryType < Types::BaseObject
      field :total, Integer, null: false
      field :by_severity, [Types::Dashboard::SeverityCountType], null: false
      field :posted_to_click_up, Integer, null: false
      field :pending_click_up, Integer, null: false
    end
  end
end

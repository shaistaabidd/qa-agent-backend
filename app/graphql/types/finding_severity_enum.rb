module Types
  class FindingSeverityEnum < BaseEnum
    description "How serious a finding is"

    value "LOW", "Minor", value: "low"
    value "MEDIUM", "Worth fixing soon", value: "medium"
    value "HIGH", "Breaks something users rely on", value: "high"
    value "CRITICAL", "Blocks users or risks data", value: "critical"
  end
end

module Types
  class AuditLogEntryAttributes < BaseInputObject
    description "An action the worker took, reported with a run's result"

    argument :action_taken, String, description: "What the worker did"
    argument :target_element, String, required: false, description: "The element it acted on"
  end
end

module Types
  module Runs
    class AuditLogEntryAttributes < Types::BaseInputObject
      argument :action_taken, String, required: true
      argument :target_element, String, required: false
    end
  end
end

class AuditLogEntry < ApplicationRecord
  belongs_to :run

  validates :action_taken, presence: true
end

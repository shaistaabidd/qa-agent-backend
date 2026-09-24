class Run < ApplicationRecord
  include AASM

  belongs_to :project
  belongs_to :scope_feature

  has_many :findings, dependent: :destroy
  has_many :audit_log_entries, dependent: :destroy

  enum :status, { queued: 0, running: 1, blocked: 2, completed: 3, failed: 4 }

  validates :role_name, presence: true

  aasm column: :status, enum: true do
    state :queued, initial: true
    state :running
    state :blocked
    state :completed
    state :failed

    event :dispatch do
      transitions from: :queued, to: :running, after: proc { update!(started_at: Time.current) }
    end

    event :block do
      transitions from: :running, to: :blocked
    end

    event :resume do
      transitions from: :blocked, to: :running
    end

    event :complete do
      transitions from: :running, to: :completed, after: proc { update!(finished_at: Time.current) }
    end

    event :fail do
      transitions from: %i[queued running blocked], to: :failed, after: proc { update!(finished_at: Time.current) }
    end
  end
end

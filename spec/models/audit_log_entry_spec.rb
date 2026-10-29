require "rails_helper"

RSpec.describe AuditLogEntry do
  it { is_expected.to belong_to(:run) }
  it { is_expected.to validate_presence_of(:action_taken) }
end

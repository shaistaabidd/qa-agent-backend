require "rails_helper"

RSpec.describe PurgeExpiredEmailLogsJob do
  it "deletes logs past the retention period and keeps recent ones" do
    create(:email_log, created_at: (EmailLog::RETENTION + 1.day).ago)
    recent = create(:email_log)

    described_class.perform_now

    expect(EmailLog.all).to contain_exactly(recent)
  end
end

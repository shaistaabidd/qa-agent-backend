require "rails_helper"

RSpec.describe PurgeExpiredSmsLogsJob do
  it "deletes logs past the retention period and keeps recent ones" do
    create(:sms_log, created_at: (SmsLog::RETENTION + 1.day).ago)
    recent = create(:sms_log)

    described_class.perform_now

    expect(SmsLog.all).to contain_exactly(recent)
  end
end

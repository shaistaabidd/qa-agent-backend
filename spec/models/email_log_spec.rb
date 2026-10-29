require "rails_helper"

RSpec.describe EmailLog do
  describe ".expired" do
    it "selects only logs older than the retention period" do
      old_log = create(:email_log, created_at: (EmailLog::RETENTION + 1.day).ago)
      create(:email_log)

      expect(described_class.expired).to contain_exactly(old_log)
    end
  end

  describe "search_document" do
    it "combines recipient and subject for search" do
      log = create(:email_log, recipient: "jane@example.com", subject: "Welcome")

      expect(log.reload.search_document).to eq("jane@example.com Welcome")
    end
  end
end

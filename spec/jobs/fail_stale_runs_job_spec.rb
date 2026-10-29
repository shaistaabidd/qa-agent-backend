require "rails_helper"

RSpec.describe FailStaleRunsJob do
  it "fails runs stuck running past the stale window and leaves the rest alone" do
    stale = create(:run, :running, started_at: (Run::STALE_AFTER + 1.minute).ago)
    fresh = create(:run, :running, started_at: 1.minute.ago)
    queued = create(:run)

    described_class.perform_now

    expect(stale.reload).to be_failed
    expect(stale.finished_at).to be_present
    expect(fresh.reload).to be_running
    expect(queued.reload).to be_queued
  end
end

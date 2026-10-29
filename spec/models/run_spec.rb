require "rails_helper"

RSpec.describe Run do
  it { is_expected.to belong_to(:project) }
  it { is_expected.to belong_to(:scope_feature) }
  it { is_expected.to validate_presence_of(:role_name) }

  it "starts queued and records started_at on dispatch" do
    run = create(:run)
    expect(run).to be_queued

    run.dispatch!

    expect(run).to be_running
    expect(run.started_at).to be_present
  end

  it "records finished_at on completion" do
    run = create(:run, :running)

    run.complete!

    expect(run).to be_completed
    expect(run.finished_at).to be_present
  end

  it "can fail from queued, running or blocked" do
    %i[queued running blocked].each do |status|
      run = create(:run, status:)

      run.fail!

      expect(run).to be_failed
    end
  end

  it "can finish from blocked" do
    run = create(:run, status: :blocked)

    run.complete!

    expect(run).to be_completed
  end

  it "cannot complete straight from queued" do
    expect { create(:run).complete! }.to raise_error(AASM::InvalidTransition)
  end

  describe ".stale" do
    it "is only runs that have been running longer than the stale window" do
      stale = create(:run, :running, started_at: (Run::STALE_AFTER + 1.minute).ago)
      create(:run, :running, started_at: 1.minute.ago)
      create(:run, status: :queued)
      create(:run, :completed, started_at: 1.day.ago)

      expect(described_class.stale).to contain_exactly(stale)
    end
  end
end

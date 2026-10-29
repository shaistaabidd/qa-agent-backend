require "rails_helper"

RSpec.describe Runs::ReceiveResult do
  let(:run) { create(:run, :running) }

  it "records audit log entries and completes the run" do
    result = described_class.call(
      run:, status: "completed",
      audit_log_entries: [{ action_taken: "clicked", target_element: "#pay-button" }]
    )

    expect(result).to be_success
    expect(run.reload).to be_completed
    expect(run.audit_log_entries.pluck(:action_taken)).to contain_exactly("clicked")
  end

  it "stores the network log and summary" do
    network_log = [{ "method" => "POST", "url" => "/graphql", "status" => 200, "durationMs" => 42 }]

    described_class.call(run:, status: "completed", network_log:, summary: { "pages" => 2 })

    expect(run.reload).to have_attributes(network_log:, summary: { "pages" => 2 })
  end

  it "caps the stored network log" do
    entries = Array.new(Runs::ReceiveResult::MAX_NETWORK_LOG + 10) { |index| { "n" => index } }

    described_class.call(run:, status: "completed", network_log: entries)

    expect(run.reload.network_log.size).to eq(Runs::ReceiveResult::MAX_NETWORK_LOG)
  end

  it "can fail or block a running run" do
    expect(described_class.call(run:, status: "failed")).to be_success
    expect(run.reload).to be_failed

    blocked = create(:run, :running)
    expect(described_class.call(run: blocked, status: "blocked")).to be_success
    expect(blocked.reload).to be_blocked
  end

  it "lets a blocked run finish" do
    blocked = create(:run, status: :blocked)

    expect(described_class.call(run: blocked, status: "completed")).to be_success
    expect(blocked.reload).to be_completed
  end

  it "is a no-op when the run already has the reported status, so a retried callback adds nothing" do
    described_class.call(run:, status: "completed", audit_log_entries: [{ action_taken: "clicked" }])

    result = described_class.call(run:, status: "completed", audit_log_entries: [{ action_taken: "clicked" }])

    expect(result).to be_success
    expect(run.reload.audit_log_entries.count).to eq(1)
  end

  it "fails, and records nothing, when the run can't move to the reported status" do
    result = described_class.call(run: create(:run, :completed), status: "failed",
                                  audit_log_entries: [{ action_taken: "late" }])

    expect(result.error.code).to eq(:invalid_run_transition)
    expect(AuditLogEntry.count).to eq(0)
  end

  it "rolls back the audit log when the status change is rejected" do
    queued = create(:run)

    expect(described_class.call(run: queued, status: "completed", audit_log_entries: [{ action_taken: "x" }]))
      .to be_failure
    expect(AuditLogEntry.count).to eq(0)
    expect(queued.reload).to be_queued
  end
end

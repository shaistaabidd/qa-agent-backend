require 'rails_helper'

RSpec.describe Runs::ReceiveResult do
  let(:run) { create(:run, status: :running) }

  it 'persists audit log entries and transitions to completed' do
    result = described_class.call(
      run: run,
      status: 'completed',
      audit_log_entries: [{ action_taken: 'clicked', target_element: '#pay-button' }]
    )

    expect(result).to be_success
    expect(run.reload).to be_completed
    expect(run.audit_log_entries.pluck(:action_taken)).to contain_exactly('clicked')
  end

  it 'stores the network log and summary' do
    network_log = [{ 'method' => 'POST', 'url' => '/graphql', 'status' => 200, 'durationMs' => 42 }]

    described_class.call(run: run, status: 'completed', network_log: network_log, summary: { 'pages' => 2 })

    expect(run.reload.network_log).to eq(network_log)
    expect(run.summary).to eq('pages' => 2)
  end

  it 'transitions to failed' do
    result = described_class.call(run: run, status: 'failed', audit_log_entries: [])

    expect(result).to be_success
    expect(run.reload).to be_failed
  end

  it 'transitions to blocked' do
    result = described_class.call(run: run, status: 'blocked', audit_log_entries: [])

    expect(result).to be_success
    expect(run.reload).to be_blocked
  end

  it 'fails cleanly on an invalid transition instead of raising' do
    completed_run = create(:run, status: :completed)

    result = described_class.call(run: completed_run, status: 'completed', audit_log_entries: [])

    expect(result).to be_failure
  end
end

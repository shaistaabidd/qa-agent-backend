require 'rails_helper'

RSpec.describe RunDispatchJob do
  let(:run) { create(:run, status: :queued) }
  let(:worker_client) { instance_double(AgentWorkerClient) }

  before { allow(AgentWorkerClient).to receive(:new).and_return(worker_client) }

  it 'dispatches to running and calls the worker' do
    allow(worker_client).to receive(:dispatch)

    described_class.perform_now(run.id)

    expect(worker_client).to have_received(:dispatch).with(run)
    expect(run.reload).to be_running
  end

  it 'marks the run failed if the worker is unreachable, instead of leaving it stuck running' do
    allow(worker_client).to receive(:dispatch).and_raise(AgentWorkerClient::DispatchError, 'boom')

    described_class.perform_now(run.id)

    expect(run.reload).to be_failed
  end

  it 'does nothing for a run that is no longer queued (already dispatched)' do
    allow(worker_client).to receive(:dispatch)
    run.update!(status: :running)

    described_class.perform_now(run.id)

    expect(worker_client).not_to have_received(:dispatch)
  end
end

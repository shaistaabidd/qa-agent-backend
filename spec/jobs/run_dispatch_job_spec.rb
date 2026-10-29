require "rails_helper"

RSpec.describe RunDispatchJob do
  let(:run) { create(:run, status: :queued) }
  let(:worker) { instance_double(AgentWorkerClient, dispatch: nil) }

  before { allow(AgentWorkerClient).to receive(:new).and_return(worker) }

  it "moves the run to running and hands it to the worker" do
    described_class.perform_now(run.id)

    expect(worker).to have_received(:dispatch).with(run)
    expect(run.reload).to be_running
  end

  it "fails the run when the worker can't be reached, rather than leaving it running" do
    allow(worker).to receive(:dispatch).and_raise(AgentWorkerClient::DispatchError, "boom")

    described_class.perform_now(run.id)

    expect(run.reload).to be_failed
  end

  it "fails the run when the worker isn't configured" do
    allow(worker).to receive(:dispatch).and_raise(AgentWorkerClient::ConfigurationError, "missing")

    described_class.perform_now(run.id)

    expect(run.reload).to be_failed
  end

  it "ignores a run that is no longer queued" do
    run.update!(status: :running)

    described_class.perform_now(run.id)

    expect(worker).not_to have_received(:dispatch)
  end

  it "ignores a run that no longer exists" do
    expect { described_class.perform_now(0) }.not_to raise_error
  end
end

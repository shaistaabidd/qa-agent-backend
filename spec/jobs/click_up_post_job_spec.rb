require "rails_helper"

RSpec.describe ClickUpPostJob do
  let(:project) { create(:project) }
  let(:finding) { create(:finding, run: create(:run, project:)) }
  let(:clickup) { instance_double(ClickUpService, create_task: "abc123") }

  before { allow(ClickUpService).to receive(:new).and_return(clickup) }

  context "when the project has a ClickUp list" do
    before { create(:integration, :click_up, project:, external_account_id: "900") }

    it "posts the task and stores its id" do
      described_class.perform_now(finding.id)

      expect(clickup).to have_received(:create_task).with("900", finding)
      expect(finding.reload.clickup_task_id).to eq("abc123")
    end

    it "does not post a finding twice" do
      finding.update!(clickup_task_id: "already-posted")

      described_class.perform_now(finding.id)

      expect(clickup).not_to have_received(:create_task)
    end

    it "logs and drops a request ClickUp refused" do
      allow(clickup).to receive(:create_task).and_raise(ClickUpService::PostError, "boom")

      expect { described_class.perform_now(finding.id) }.not_to raise_error
      expect(finding.reload.clickup_task_id).to be_nil
    end

    it "retries when ClickUp is rate limited or down" do
      allow(clickup).to receive(:create_task).and_raise(ClickUpService::TransientError, "429")

      described_class.perform_later(finding.id)

      expect { perform_enqueued_jobs }.not_to raise_error
      expect(enqueued_jobs.size).to eq(1)
    end
  end

  it "does nothing without a ClickUp list" do
    described_class.perform_now(finding.id)

    expect(clickup).not_to have_received(:create_task)
  end
end

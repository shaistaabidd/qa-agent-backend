require 'rails_helper'

RSpec.describe ClickUpPostJob do
  let(:project) { create(:project) }
  let(:run) { create(:run, project: project) }
  let(:finding) { create(:finding, run: run) }
  let(:clickup_client) { instance_double(ClickUpService) }

  before do
    allow(ClickUpService).to receive(:new).and_return(clickup_client)
    allow(clickup_client).to receive(:create_task)
  end

  context 'when the project has a connected ClickUp list' do
    before { create(:integration, project: project, integration_type: :click_up, external_account_id: '900') }

    it 'posts the task and stores the returned clickup_task_id' do
      allow(clickup_client).to receive(:create_task).with('900', finding).and_return('abc123')

      described_class.perform_now(finding.id)

      expect(finding.reload.clickup_task_id).to eq('abc123')
    end

    it 'is idempotent — does not re-post a finding that already has a task id' do
      finding.update!(clickup_task_id: 'already-posted')

      described_class.perform_now(finding.id)

      expect(clickup_client).not_to have_received(:create_task)
    end

    it 'logs and does not raise if ClickUp is unreachable' do
      allow(clickup_client).to receive(:create_task).and_raise(ClickUpService::PostError, 'boom')

      expect { described_class.perform_now(finding.id) }.not_to raise_error
      expect(finding.reload.clickup_task_id).to be_nil
    end
  end

  context 'when the project has no ClickUp integration configured' do
    it 'does nothing' do
      described_class.perform_now(finding.id)

      expect(clickup_client).not_to have_received(:create_task)
    end
  end
end

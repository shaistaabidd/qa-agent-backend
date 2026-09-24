require 'rails_helper'

RSpec.describe Integrations::ConnectClickUp do
  let(:project) { create(:project) }

  it 'creates the click_up integration with the given list id' do
    result = described_class.call(project: project, list_id: '900')

    expect(result).to be_success
    integration = project.integrations.find_by(integration_type: :click_up)
    expect(integration.external_account_id).to eq('900')
    expect(integration.connected_at).to be_present
  end

  it 'is idempotent — reconnecting updates the existing integration' do
    described_class.call(project: project, list_id: '111')

    expect { described_class.call(project: project, list_id: '222') }.not_to change(Integration, :count)

    integration = project.integrations.find_by(integration_type: :click_up)
    expect(integration.external_account_id).to eq('222')
  end
end

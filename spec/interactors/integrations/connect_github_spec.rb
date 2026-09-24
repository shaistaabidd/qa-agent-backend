require 'rails_helper'

RSpec.describe Integrations::ConnectGithub do
  let(:project) { create(:project) }

  it "creates the integration and links it as the project's repo_connection" do
    result = described_class.call(project: project, installation_id: '12345', repo_full_name: 'acme/checkout-app')

    expect(result).to be_success
    integration = project.reload.repo_connection
    expect(integration).to be_github
    expect(integration.external_account_id).to eq('12345')
    expect(integration.repo_full_name).to eq('acme/checkout-app')
    expect(integration.connected_at).to be_present
  end

  it 'is idempotent — reconnecting updates the existing integration instead of duplicating it' do
    described_class.call(project: project, installation_id: '111', repo_full_name: 'acme/old-repo')

    expect do
      described_class.call(project: project, installation_id: '222', repo_full_name: 'acme/new-repo')
    end.not_to change(Integration, :count)

    expect(project.reload.repo_connection.repo_full_name).to eq('acme/new-repo')
  end

  it 'fails when repo_full_name is missing' do
    result = described_class.call(project: project, installation_id: '12345', repo_full_name: nil)

    expect(result).to be_failure
  end
end

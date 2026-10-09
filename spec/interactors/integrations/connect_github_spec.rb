require 'rails_helper'

RSpec.describe Integrations::ConnectGithub do
  let(:project) { create(:project) }
  let(:github_service) { instance_double(GitHubAppService, repository_names: %w[acme/checkout-app acme/new-repo]) }

  before { allow(GitHubAppService).to receive(:for_installation).with('12345').and_return(github_service) }

  def install_app!
    create(:integration, project: project, external_account_id: '12345', repo_full_name: nil, connected_at: nil)
  end

  it "links a repo the installation can access as the project's repo_connection" do
    install_app!

    result = described_class.call(project: project, repo_full_name: 'acme/checkout-app')

    expect(result).to be_success
    integration = project.reload.repo_connection
    expect(integration).to be_github
    expect(integration.external_account_id).to eq('12345')
    expect(integration.repo_full_name).to eq('acme/checkout-app')
    expect(integration.connected_at).to be_present
  end

  it 'is idempotent — switching repos updates the existing integration instead of duplicating it' do
    install_app!
    described_class.call(project: project, repo_full_name: 'acme/checkout-app')

    expect do
      described_class.call(project: project, repo_full_name: 'acme/new-repo')
    end.not_to change(Integration, :count)

    expect(project.reload.repo_connection.repo_full_name).to eq('acme/new-repo')
  end

  it 'fails when the GitHub App is not installed yet' do
    result = described_class.call(project: project, repo_full_name: 'acme/checkout-app')

    expect(result).to be_failure
    expect(result.error).to match(/Install the GitHub App/)
  end

  it 'fails for a repo the installation was not granted' do
    install_app!

    result = described_class.call(project: project, repo_full_name: 'someone-else/secret')

    expect(result).to be_failure
    expect(project.reload.repo_connection).to be_nil
  end
end

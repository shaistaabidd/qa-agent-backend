require 'rails_helper'

RSpec.describe Integrations::LinkGithubInstallation do
  let(:user) { create(:user) }
  let(:project) { create(:project) }
  let(:state) { GitHubInstallState.generate(project: project, user: user) }
  let(:authorization) { instance_double(GitHubUserAuthorization) }

  before do
    allow(GitHubUserAuthorization).to receive(:new).with('oauth-code').and_return(authorization)
    allow(authorization).to receive(:can_access_installation?).and_return(false)
    allow(authorization).to receive(:can_access_installation?).with('777').and_return(true)
  end

  def call(**overrides)
    described_class.call(user: user, state: state, installation_id: '777', code: 'oauth-code', **overrides)
  end

  it 'stores the installation on the project without picking a repo yet' do
    result = call

    expect(result).to be_success
    integration = project.integrations.github.first
    expect(integration.external_account_id).to eq('777')
    expect(integration.repo_full_name).to be_nil
    expect(project.reload.repo_connection).to be_nil
  end

  it "rejects an installation the user can't access" do
    result = call(installation_id: '999')

    expect(result).to be_failure
    expect(project.integrations).to be_empty
  end

  it 'rejects a tampered state' do
    expect(call(state: "#{state}x")).to be_failure
  end

  it 'rejects a state started by a different user' do
    expect(call(user: create(:user))).to be_failure
  end

  it 'unlinks the old repo when a different installation is linked' do
    integration = create(:integration, project: project, external_account_id: '111')
    project.update!(repo_connection: integration)

    call

    expect(integration.reload.repo_full_name).to be_nil
    expect(project.reload.repo_connection).to be_nil
  end

  it 'keeps the linked repo when the same installation is re-confirmed' do
    integration = create(:integration, project: project, external_account_id: '777')
    project.update!(repo_connection: integration)

    call

    expect(project.reload.repo_connection.repo_full_name).to eq('acme/checkout-app')
  end
end

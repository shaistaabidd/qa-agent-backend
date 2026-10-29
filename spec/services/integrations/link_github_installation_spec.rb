require "rails_helper"

RSpec.describe Integrations::LinkGithubInstallation do
  let(:user) { create(:user) }
  let(:project) { create(:project) }
  let(:state) { GitHubInstallState.generate(project:, user:) }
  let(:authorization) { instance_double(GitHubUserAuthorization) }

  before do
    allow(GitHubUserAuthorization).to receive(:new).with("oauth-code").and_return(authorization)
    allow(authorization).to receive(:can_access_installation?).and_return(false)
    allow(authorization).to receive(:can_access_installation?).with("777").and_return(true)
  end

  def call(**overrides)
    described_class.call(user:, state:, installation_id: "777", code: "oauth-code", **overrides)
  end

  it "stores the installation on the project without choosing a repository" do
    expect(call).to be_success

    expect(project.integrations.github.sole).to have_attributes(external_account_id: "777", repo_full_name: nil)
    expect(project.reload.repo_connection).to be_nil
  end

  it "rejects an installation the user can't access" do
    expect(call(installation_id: "999").error.code).to eq(:github_access_denied)
    expect(project.integrations).to be_empty
  end

  it "rejects a tampered state" do
    expect(call(state: "#{state}x").error.code).to eq(:github_link_expired)
  end

  it "rejects a state another user started" do
    expect(call(user: create(:user)).error.code).to eq(:github_wrong_user)
  end

  it "unlinks the old repository when a different installation is linked" do
    integration = create(:integration, project:, external_account_id: "111")
    project.update!(repo_connection: integration)

    call

    expect(integration.reload.repo_full_name).to be_nil
    expect(project.reload.repo_connection).to be_nil
  end

  it "keeps the linked repository when the same installation is confirmed again" do
    project.update!(repo_connection: create(:integration, project:, external_account_id: "777"))

    call

    expect(project.reload.repo_connection.repo_full_name).to eq("acme/checkout-app")
  end

  it "fails with a generic GitHub error when GitHub rejects the code" do
    allow(authorization).to receive(:can_access_installation?).and_raise(GitHubUserAuthorization::AuthorizationError)

    expect(call.error.code).to eq(:github_failed)
  end
end

require "rails_helper"

RSpec.describe Integrations::AuthorizeGithubUser do
  let(:user) { create(:user) }
  let(:project) { create(:project) }
  let(:state) { GitHubInstallState.generate(project:, user:) }
  let(:authorization) { instance_double(GitHubUserAuthorization) }
  let(:installations) { [{ id: 777, account_login: "Staunchglobal", account_type: "Organization" }] }

  before do
    allow(GitHubUserAuthorization).to receive(:new).with("oauth-code").and_return(authorization)
    allow(authorization).to receive(:installations).and_return(installations)
  end

  it "returns the user's installations and a choice token limited to them" do
    result = described_class.call(user:, state:, code: "oauth-code")

    expect(result).to be_success
    expect(result.value.installations).to eq(installations)
    expect(GitHubInstallState.verify_choice(result.value.choice_token))
      .to eq("project_id" => project.id, "user_id" => user.id, "installation_ids" => [777])
  end

  it "rejects a state another user started" do
    expect(described_class.call(user: create(:user), state:, code: "oauth-code").error.code).to eq(:github_wrong_user)
  end

  it "rejects an expired or tampered state" do
    expect(described_class.call(user:, state: "#{state}x", code: "oauth-code").error.code).to eq(:github_link_expired)
  end
end

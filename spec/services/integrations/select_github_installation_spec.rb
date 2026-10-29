require "rails_helper"

RSpec.describe Integrations::SelectGithubInstallation do
  let(:user) { create(:user) }
  let(:project) { create(:project) }
  let(:choice_token) do
    GitHubInstallState.generate_choice(project_id: project.id, user_id: user.id, installation_ids: [777])
  end

  def call(**overrides) = described_class.call(user:, choice_token:, installation_id: "777", **overrides)

  it "links an installation from the confirmed list" do
    expect(call).to be_success
    expect(project.integrations.github.sole.external_account_id).to eq("777")
  end

  it "rejects an installation outside the confirmed list" do
    expect(call(installation_id: "999").error.code).to eq(:github_access_denied)
    expect(project.integrations).to be_empty
  end

  it "rejects a choice token issued to another user" do
    expect(call(user: create(:user)).error.code).to eq(:github_access_denied)
  end

  it "rejects a tampered choice token" do
    expect(call(choice_token: "#{choice_token}x").error.code).to eq(:github_link_expired)
  end
end

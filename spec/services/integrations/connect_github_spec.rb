require "rails_helper"

RSpec.describe Integrations::ConnectGithub do
  let(:project) { create(:project) }
  let(:github) { instance_double(GitHubAppService, repository_names: %w[acme/checkout-app acme/new-repo]) }

  before { allow(GitHubAppService).to receive(:for_installation).with("12345").and_return(github) }

  def install_app!
    create(:integration, project:, external_account_id: "12345", repo_full_name: nil, connected_at: nil)
  end

  it "links a repository the installation can see as the project's repo connection" do
    install_app!

    result = described_class.call(project:, repo_full_name: "acme/checkout-app")

    expect(result).to be_success
    expect(project.reload.repo_connection).to have_attributes(
      external_account_id: "12345", repo_full_name: "acme/checkout-app", connected_at: be_present
    )
  end

  it "switches repositories without adding a second integration" do
    install_app!
    described_class.call(project:, repo_full_name: "acme/checkout-app")

    expect { described_class.call(project:, repo_full_name: "acme/new-repo") }.not_to change(Integration, :count)
    expect(project.reload.repo_connection.repo_full_name).to eq("acme/new-repo")
  end

  it "fails when the GitHub App is not installed" do
    expect(described_class.call(project:, repo_full_name: "acme/checkout-app").error.code)
      .to eq(:github_not_installed)
  end

  it "fails for a repository the installation was not granted" do
    install_app!

    result = described_class.call(project:, repo_full_name: "someone-else/secret")

    expect(result.error.code).to eq(:github_repo_inaccessible)
    expect(project.reload.repo_connection).to be_nil
  end

  it "fails with a generic GitHub error when GitHub is unreachable" do
    install_app!
    allow(github).to receive(:repository_names).and_raise(Octokit::ServerError)

    expect(described_class.call(project:, repo_full_name: "acme/checkout-app").error.code).to eq(:github_failed)
  end
end

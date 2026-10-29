require "rails_helper"

RSpec.describe ScopeFeatures::ScanCodebase do
  let(:project) { create(:project) }

  context "without a connected repository" do
    it "fails without calling GitHub" do
      allow(GitHubAppService).to receive(:for_installation)

      result = described_class.call(project:)

      expect(result.error.code).to eq(:repo_not_connected)
      expect(GitHubAppService).not_to have_received(:for_installation)
    end
  end

  context "with a connected repository" do
    let(:github) { instance_double(GitHubAppService) }
    let(:analyzer) { instance_double(CodebaseAnalyzer, extract_features: features) }
    let(:features) do
      [
        { name: "GET checkout", route: "checkout", source: "config/routes.rb" },
        { name: "POST checkout", route: "checkout", source: "config/routes.rb" }
      ]
    end

    before do
      project.update!(repo_connection: create(:integration, project:, external_account_id: "999"))
      allow(GitHubAppService).to receive(:for_installation).with("999").and_return(github)
      allow(CodebaseAnalyzer).to receive(:new).with(github, "acme/checkout-app").and_return(analyzer)
    end

    it "records one scope feature per extracted feature" do
      result = described_class.call(project:)

      expect(result).to be_success
      expect(project.scope_features.pluck(:name)).to contain_exactly("GET checkout", "POST checkout")
    end

    it "keeps existing features, and their approval, across rescans" do
      described_class.call(project:)
      project.scope_features.first.update!(approved: true)

      expect { described_class.call(project:) }.not_to change(ScopeFeature, :count)
      expect(project.scope_features.where(approved: true).count).to eq(1)
    end

    it "fails with a generic GitHub error when GitHub rejects the request" do
      allow(analyzer).to receive(:extract_features).and_raise(Octokit::Unauthorized)

      expect(described_class.call(project:).error.code).to eq(:github_failed)
    end
  end
end

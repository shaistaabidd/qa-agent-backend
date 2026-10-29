require "rails_helper"

RSpec.describe "Integration queries", type: :graphql do
  let(:admin) { create(:user) }
  let(:member) { create(:user) }
  let(:project) { create(:project) }

  before do
    create(:membership, :admin, user: admin, project:)
    create(:membership, user: member, project:)
  end

  describe "fetchGithubInstallUrl" do
    let(:query) { "query($id: ID!) { fetchGithubInstallUrl(projectId: $id) }" }

    before do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("GITHUB_APP_SLUG", nil).and_return("qa-agent")
    end

    it "gives a project admin the install URL with state bound to the project and user" do
      url = URI.parse(execute_graphql(query, variables: { id: project.id.to_s }, as: admin)
                        .dig("data", "fetchGithubInstallUrl"))

      expect(url.to_s).to start_with("https://github.com/apps/qa-agent/installations/new")
      state = Rack::Utils.parse_query(url.query).fetch("state")
      expect(GitHubInstallState.verify(state)).to eq("project_id" => project.id, "user_id" => admin.id)
    end

    it "is forbidden to a plain member" do
      expect(error_codes(execute_graphql(query, variables: { id: project.id.to_s }, as: member))).to eq(["FORBIDDEN"])
    end
  end

  describe "fetchGithubAuthorizeUrl" do
    it "gives a project admin a sign-in URL and refuses a plain member" do
      query = "query($id: ID!) { fetchGithubAuthorizeUrl(projectId: $id) }"
      allow(GitHubUserAuthorization).to receive(:authorize_url).and_return("https://github.com/login/oauth/authorize")

      expect(execute_graphql(query, variables: { id: project.id.to_s }, as: admin).dig("data",
                                                                                       "fetchGithubAuthorizeUrl"))
        .to start_with("https://github.com/")
      expect(error_codes(execute_graphql(query, variables: { id: project.id.to_s }, as: member))).to eq(["FORBIDDEN"])
    end
  end

  describe "allGithubRepositories" do
    let(:query) { "query($id: ID!) { allGithubRepositories(projectId: $id) }" }

    it "lists the repositories the installation can see" do
      create(:integration, project:, external_account_id: "999")
      github = instance_double(GitHubAppService, repository_names: %w[acme/app acme/api])
      allow(GitHubAppService).to receive(:for_installation).with("999").and_return(github)

      expect(execute_graphql(query, variables: { id: project.id.to_s }, as: admin).dig("data",
                                                                                       "allGithubRepositories"))
        .to eq(%w[acme/app acme/api])
    end

    it "asks to install the App first" do
      expect(error_codes(execute_graphql(query, variables: { id: project.id.to_s }, as: admin)))
        .to eq(["GITHUB_NOT_INSTALLED"])
    end

    it "hides GitHub's error details" do
      create(:integration, project:, external_account_id: "999")
      github = instance_double(GitHubAppService)
      allow(github).to receive(:repository_names).and_raise(Octokit::Unauthorized)
      allow(GitHubAppService).to receive(:for_installation).and_return(github)

      result = execute_graphql(query, variables: { id: project.id.to_s }, as: admin)

      expect(error_codes(result)).to eq(["GITHUB_FAILED"])
      expect(result.dig("errors", 0, "message")).to eq(I18n.t("errors.github_failed"))
    end

    it "is forbidden to a plain member" do
      expect(error_codes(execute_graphql(query, variables: { id: project.id.to_s }, as: member))).to eq(["FORBIDDEN"])
    end
  end
end

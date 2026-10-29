require "rails_helper"

RSpec.describe "Integration mutations", type: :graphql do
  let(:admin) { create(:user) }
  let(:member) { create(:user) }
  let(:project) { create(:project) }

  before do
    create(:membership, :admin, user: admin, project:)
    create(:membership, user: member, project:)
  end

  describe "connectGithub" do
    let(:mutation) do
      <<~GQL
        mutation($input: ConnectGithubInput!) { connectGithub(input: $input) { project { repoConnected repoFullName } } }
      GQL
    end
    let(:input) { { projectId: project.id.to_s, repoFullName: "acme/checkout-app" } }

    before do
      create(:integration, project:, external_account_id: "999", repo_full_name: nil)
      github = instance_double(GitHubAppService, repository_names: ["acme/checkout-app"])
      allow(GitHubAppService).to receive(:for_installation).with("999").and_return(github)
    end

    it "lets a project admin connect a repository from the installation" do
      result = execute_graphql(mutation, variables: { input: }, as: admin)

      expect(result.dig("data", "connectGithub", "project"))
        .to eq("repoConnected" => true, "repoFullName" => "acme/checkout-app")
    end

    it "is forbidden to a plain member" do
      expect(error_codes(execute_graphql(mutation, variables: { input: }, as: member))).to eq(["FORBIDDEN"])
    end
  end

  describe "connectClickUp" do
    let(:mutation) do
      "mutation($input: ConnectClickUpInput!) { connectClickUp(input: $input) { project { id } } }"
    end
    let(:input) { { projectId: project.id.to_s, listId: "900" } }

    it "lets a project admin set the ClickUp list" do
      result = execute_graphql(mutation, variables: { input: }, as: admin)

      expect(result["errors"]).to be_nil
      expect(project.integrations.click_up.sole.external_account_id).to eq("900")
    end

    it "is forbidden to a plain member" do
      expect(error_codes(execute_graphql(mutation, variables: { input: }, as: member))).to eq(["FORBIDDEN"])
    end
  end

  describe "completeGithubInstallation" do
    let(:mutation) do
      <<~GQL
        mutation($input: CompleteGithubInstallationInput!) {
          completeGithubInstallation(input: $input) { project { githubInstalled } }
        }
      GQL
    end
    let(:state) { GitHubInstallState.generate(project:, user: admin) }
    let(:input) { { state:, installationId: "777", code: "oauth-code" } }

    before do
      authorization = instance_double(GitHubUserAuthorization, can_access_installation?: true)
      allow(GitHubUserAuthorization).to receive(:new).with("oauth-code").and_return(authorization)
    end

    it "stores the installation on the project" do
      result = execute_graphql(mutation, variables: { input: }, as: admin)

      expect(result.dig("data", "completeGithubInstallation", "project", "githubInstalled")).to be(true)
    end

    it "is forbidden when the state belongs to a project the caller can't manage" do
      state = GitHubInstallState.generate(project:, user: member)

      result = execute_graphql(mutation, variables: { input: input.merge(state:) }, as: member)

      expect(error_codes(result)).to eq(["FORBIDDEN"])
      expect(project.integrations).to be_empty
    end

    it "refuses a state another user started" do
      result = execute_graphql(mutation, variables: { input: }, as: create(:user))

      expect(error_codes(result)).to eq(["NOT_FOUND"])
    end

    it "refuses a tampered state" do
      result = execute_graphql(mutation, variables: { input: input.merge(state: "#{state}x") }, as: admin)

      expect(error_codes(result)).to eq(["GITHUB_LINK_EXPIRED"])
    end
  end

  describe "authorizeGithubUser and selectGithubInstallation" do
    let(:state) { GitHubInstallState.generate(project:, user: admin) }

    it "lists the installations the user can reach, then links the chosen one" do
      installations = [{ id: 777, account_login: "Staunchglobal", account_type: "Organization" }]
      authorization = instance_double(GitHubUserAuthorization, installations:)
      allow(GitHubUserAuthorization).to receive(:new).with("oauth-code").and_return(authorization)

      listed = execute_graphql(
        "mutation($input: AuthorizeGithubUserInput!) { authorizeGithubUser(input: $input) " \
        "{ choiceToken installations { id accountLogin accountType } } }",
        variables: { input: { state:, code: "oauth-code" } }, as: admin
      ).dig("data", "authorizeGithubUser")
      expect(listed["installations"]).to eq([{ "id" => "777", "accountLogin" => "Staunchglobal",
                                               "accountType" => "Organization" }])

      linked = execute_graphql(
        "mutation($input: SelectGithubInstallationInput!) { selectGithubInstallation(input: $input) " \
        "{ project { githubInstalled } } }",
        variables: { input: { choiceToken: listed["choiceToken"], installationId: "777" } }, as: admin
      )
      expect(linked.dig("data", "selectGithubInstallation", "project", "githubInstalled")).to be(true)
    end
  end
end

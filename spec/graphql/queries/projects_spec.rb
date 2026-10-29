require "rails_helper"

RSpec.describe "Project queries", type: :graphql do
  let(:user) { create(:user) }
  let(:project) { create(:project) }

  before { create(:membership, user:, project:) }

  describe "allProjects" do
    let(:query) do
      <<~GQL
        query($filter: PaginatedFilterInput) {
          allProjects(filter: $filter) { count totalPages allData { id name myRole repoConnected githubInstalled } }
        }
      GQL
    end

    it "lists only the user's projects, newest first, with their role" do
      create(:membership, :admin, user:, project: create(:project, name: "Newer", created_at: 1.minute.from_now))
      create(:project, name: "Not mine")

      result = execute_graphql(query, as: user).dig("data", "allProjects")

      expect(result["count"]).to eq(2)
      expect(result["allData"].pluck("name")).to eq(["Newer", project.name])
      expect(result["allData"].pluck("myRole")).to eq(%w[ADMIN MEMBER])
    end

    it "lets a super admin see every project, with no role in the ones they don't belong to" do
      other = create(:project)

      projects = execute_graphql(query, as: create(:user, :super_admin)).dig("data", "allProjects", "allData")

      expect(projects.pluck("id")).to contain_exactly(project.id.to_s, other.id.to_s)
      expect(projects.pluck("myRole")).to all(be_nil)
    end

    it "reports whether GitHub is installed and a repository is linked" do
      project.update!(repo_connection: create(:integration, project:))

      expect(execute_graphql(query, as: user).dig("data", "allProjects", "allData", 0))
        .to include("repoConnected" => true, "githubInstalled" => true)
    end

    it "pages and caps the page size" do
      create_list(:membership, 3, user:)

      page = execute_graphql(query, variables: { filter: { page: 2, perPage: 2 } }, as: user)
             .dig("data", "allProjects")

      expect(page).to include("count" => 4, "totalPages" => 2)
      expect(page["allData"].size).to eq(2)
      expect(execute_graphql(query, variables: { filter: { perPage: 100_000 } }, as: user)["errors"]).to be_nil
    end

    it "loads nothing it wasn't asked for, so a minimal query doesn't trip the eager-loading checks" do
      create(:membership, user:)
      project.update!(repo_connection: create(:integration, project:))

      result = execute_graphql("{ allProjects { allData { id name repoConnected } } }", as: user)

      expect(result["errors"]).to be_nil
      expect(result.dig("data", "allProjects", "allData").size).to eq(2)
    end

    it "requires sign-in" do
      expect(error_codes(execute_graphql(query))).to eq(["UNAUTHENTICATED"])
    end
  end

  describe "fetchProject" do
    let(:query) { "query($id: ID!) { fetchProject(id: $id) { name targetUrl myRole } }" }

    it "returns a project the user belongs to" do
      result = execute_graphql(query, variables: { id: project.id.to_s }, as: user)

      expect(result.dig("data", "fetchProject")).to eq("name" => project.name, "targetUrl" => project.target_url,
                                                       "myRole" => "MEMBER")
    end

    it "answers not found, not forbidden, to a non-member so ids can't be probed" do
      result = execute_graphql(query, variables: { id: project.id.to_s }, as: create(:user))

      expect(error_codes(result)).to eq(["NOT_FOUND"])
    end
  end

  describe "fetchCoverage" do
    let(:query) do
      "query($id: ID!) { fetchCoverage(projectId: $id) { totalScopeFeatures approvedScopeFeatures " \
        "testedScopeFeatures coveragePercentage } }"
    end

    def coverage = execute_graphql(query, variables: { id: project.id.to_s }, as: user).dig("data", "fetchCoverage")

    it "measures tested (has a run) against approved scope features, not all of them" do
      tested = create(:scope_feature, :approved, project:)
      create(:run, project:, scope_feature: tested)
      create(:scope_feature, :approved, project:)
      create(:scope_feature, project:)

      expect(coverage).to eq("totalScopeFeatures" => 3, "approvedScopeFeatures" => 2, "testedScopeFeatures" => 1,
                             "coveragePercentage" => 50.0)
    end

    it "is 0% rather than dividing by zero when nothing is approved" do
      expect(coverage["coveragePercentage"]).to eq(0.0)
    end

    it "counts a feature with several runs once" do
      feature = create(:scope_feature, :approved, project:)
      create_list(:run, 3, project:, scope_feature: feature)

      expect(coverage["testedScopeFeatures"]).to eq(1)
    end
  end
end

require "rails_helper"

# The schema caps query depth and complexity (see QaAgentBackendSchema). These are the heaviest
# documents the web app is expected to send, each selecting every field it can; they must fit.
RSpec.describe "Schema limits", type: :graphql do
  let(:user) { create(:user) }
  let(:project) { create(:project) }
  let(:run) { create(:run, :completed, project:) }

  before do
    create(:membership, :admin, user:, project:)
    create(:finding, run:)
    create(:audit_log_entry, run:)
    create(:role_credential, project:)
  end

  def run_query(query) = execute_graphql(query, variables: { id: project.id.to_s, runId: run.id.to_s }, as: user)

  it "fits the project page: project, coverage, summary, credentials and scope features in one document" do
    result = run_query(<<~GQL)
      query($id: ID!) {
        fetchProject(id: $id) { id name targetUrl repoConnected githubInstalled repoFullName myRole createdAt }
        fetchCoverage(projectId: $id) { totalScopeFeatures approvedScopeFeatures testedScopeFeatures coveragePercentage }
        fetchFindingsSummary(projectId: $id) {
          total resolved totalFindings postedToClickUp pendingClickUp bySeverity { severity count }
        }
        allRoleCredentials(projectId: $id) { id roleName createdAt updatedAt }
        allScopeFeatures(projectId: $id, filter: { perPage: 100 }) {
          count currentPage totalPages nextPage prevPage
          allData { id name route source approved createdAt }
        }
      }
    GQL

    expect(result["errors"]).to be_nil
  end

  it "fits a full page of runs with their scope feature and audit trail" do
    result = run_query(<<~GQL)
      query($id: ID!) {
        allRuns(projectId: $id, filter: { perPage: 100, status: COMPLETED }) {
          count currentPage totalPages nextPage prevPage
          allData {
            id roleName status startedAt finishedAt createdAt networkLog summary
            scopeFeature { id name route source approved createdAt }
            auditLogEntries { id actionTaken targetElement createdAt }
          }
        }
      }
    GQL

    expect(result["errors"]).to be_nil
    expect(result.dig("data", "allRuns", "allData", 0, "auditLogEntries")).not_to be_empty
  end

  it "fits one run's detail, and a full page of findings with their issue stats" do
    result = run_query(<<~GQL)
      query($id: ID!, $runId: ID!) {
        fetchRun(id: $runId) {
          id roleName status startedAt finishedAt createdAt networkLog summary
          scopeFeature { id name route source approved createdAt }
          auditLogEntries { id actionTaken targetElement createdAt }
        }
        allFindings(projectId: $id, filter: { perPage: 100 }) {
          count currentPage totalPages nextPage prevPage
          allData {
            id runId title reproSteps severity category source details fingerprint screenshotUrl clickupTaskId
            createdAt timesSeen firstSeenAt lastSeenAt issueStatus
          }
        }
      }
    GQL

    expect(result["errors"]).to be_nil
  end

  it "still rejects an abusively expensive query" do
    expensive = "query { #{(1..400).map { "a#{it}: fetchProject(id: \"1\") { id name } " }.join} }"

    expect(execute_graphql(expensive, as: user)["errors"].first["message"]).to match(/complexity/i)
  end
end

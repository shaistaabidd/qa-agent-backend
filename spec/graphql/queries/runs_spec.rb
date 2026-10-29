require "rails_helper"

RSpec.describe "Run queries", type: :graphql do
  let(:user) { create(:user) }
  let(:project) { create(:project) }

  before { create(:membership, user:, project:) }

  describe "allRuns" do
    let(:query) do
      <<~GQL
        query($id: ID!, $filter: RunFilterInput) {
          allRuns(projectId: $id, filter: $filter) { allData { status scopeFeature { name } auditLogEntries { actionTaken } } }
        }
      GQL
    end

    def statuses(filter = {})
      execute_graphql(query, variables: { id: project.id.to_s, filter: }, as: user)
        .dig("data", "allRuns", "allData").pluck("status")
    end

    before do
      create(:run, project:, status: :queued)
      create(:run, :running, project:)
      create(:run, :completed, project:)
    end

    it "lists every run when no filter is given" do
      expect(statuses).to contain_exactly("QUEUED", "RUNNING", "COMPLETED")
    end

    it "filters by status" do
      expect(statuses(status: "RUNNING")).to eq(["RUNNING"])
    end

    it "loads only what the list asks for: the queue's own fields, as the web app selects them" do
      create(:audit_log_entry, run: Run.running.first)

      result = execute_graphql(
        "query($id: ID!) { allRuns(projectId: $id) { allData { id status roleName scopeFeature { id name } } } }",
        variables: { id: project.id.to_s }, as: user
      )

      expect(result["errors"]).to be_nil
      expect(result.dig("data", "allRuns", "allData").size).to eq(3)
    end

    it "includes what the worker did without a query per run" do
      create(:audit_log_entry, run: Run.running.first)

      runs = execute_graphql(query, variables: { id: project.id.to_s }, as: user).dig("data", "allRuns", "allData")

      expect(runs.sum { it["auditLogEntries"].size }).to eq(1)
    end
  end

  describe "fetchRun" do
    let(:run) { create(:run, project:) }
    let(:query) { "query($id: ID!) { fetchRun(id: $id) { id roleName status networkLog summary } }" }

    it "returns a run in one of the user's projects" do
      expect(execute_graphql(query, variables: { id: run.id.to_s }, as: user).dig("data", "fetchRun"))
        .to include("id" => run.id.to_s, "roleName" => "admin", "status" => "QUEUED")
    end

    it "answers not found for someone else's run" do
      result = execute_graphql(query, variables: { id: create(:run).id.to_s }, as: user)

      expect(error_codes(result)).to eq(["NOT_FOUND"])
    end
  end
end

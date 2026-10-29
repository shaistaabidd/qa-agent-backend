require "rails_helper"

RSpec.describe "Finding queries", type: :graphql do
  let(:user) { create(:user) }
  let(:project) { create(:project) }
  let(:feature) { create(:scope_feature, project:) }

  before { create(:membership, user:, project:) }

  def finished_run(**attributes) = create(:run, :completed, project:, scope_feature: feature, **attributes)

  describe "allFindings" do
    let(:query) do
      <<~GQL
        query($id: ID!, $filter: FindingFilterInput) {
          allFindings(projectId: $id, filter: $filter) {
            allData { title runId timesSeen issueStatus firstSeenAt lastSeenAt source severity }
          }
        }
      GQL
    end

    def rows(filter = {})
      execute_graphql(query, variables: { id: project.id.to_s, filter: }, as: user).dig("data", "allFindings",
                                                                                        "allData")
    end

    def issues = rows.index_by { it["title"] }

    it "lists a member's findings and nothing from other projects" do
      create(:finding, run: finished_run, title: "Mine")
      create(:finding, title: "Elsewhere")

      expect(rows.pluck("title")).to eq(["Mine"])
    end

    it "shows one row per issue, its latest occurrence, with stats" do
      first = finished_run
      second = finished_run
      create(:finding, run: first, title: "TypeError: x", fingerprint: "js:x")
      create(:finding, run: second, title: "TypeError: x", fingerprint: "js:x")

      expect(issues.fetch("TypeError: x")).to include("runId" => second.id.to_s, "timesSeen" => 2,
                                                      "issueStatus" => "ongoing")
    end

    it "marks issues new, resolved and regressed" do
      first = finished_run
      finished_run
      third = finished_run
      create(:finding, run: first, title: "Gone", fingerprint: "gone")
      create(:finding, run: first, title: "Flaky", fingerprint: "flaky")
      create(:finding, run: third, title: "Flaky", fingerprint: "flaky")
      create(:finding, run: third, title: "Fresh", fingerprint: "fresh")

      expect(issues.transform_values { it["issueStatus"] })
        .to include("Gone" => "resolved", "Flaky" => "regressed", "Fresh" => "new")
    end

    it "goes back to ongoing once a regressed issue keeps happening" do
      first = finished_run
      finished_run
      back = finished_run
      again = finished_run
      [first, back, again].each { create(:finding, run: it, title: "Flaky", fingerprint: "flaky") }

      expect(issues.fetch("Flaky")["issueStatus"]).to eq("ongoing")
    end

    it "doesn't resolve an issue in a run that never reached its page or tab" do
      create(:finding, run: finished_run, title: "N+1", fingerprint: "n1", details: { "view" => "/p/:id > Issues" })
      finished_run(summary: { "views" => ["/p/:id", "/p/:id > Credentials"] })

      expect(issues.fetch("N+1")["issueStatus"]).to eq("new")
    end

    it "resolves it once a run reaches that view and the issue is gone" do
      create(:finding, run: finished_run, title: "N+1", fingerprint: "n1", details: { "view" => "/p/:id > Issues" })
      finished_run(summary: { "views" => ["/p/:id", "/p/:id > Issues"] })

      expect(issues.fetch("N+1")["issueStatus"]).to eq("resolved")
    end

    it "lists every finding of one run, ungrouped, when filtered by run" do
      target = finished_run
      create(:finding, run: target, title: "A", fingerprint: "a")
      create(:finding, run: finished_run, title: "A", fingerprint: "a")

      expect(rows(runId: target.id.to_s).pluck("runId")).to eq([target.id.to_s])
    end

    it "can list every finding instead of one per issue" do
      create(:finding, run: finished_run, title: "A", fingerprint: "a")
      create(:finding, run: finished_run, title: "A", fingerprint: "a")

      expect(rows(grouped: false).size).to eq(2)
    end

    it "filters by severity and source" do
      run = finished_run
      create(:finding, run:, title: "Slow query", severity: :low, details: { "type" => "slow_query" })
      create(:finding, run:, title: "Crash", severity: :critical, details: { "type" => "uncaught_exception" })

      expect(rows(severity: "CRITICAL").pluck("title")).to eq(["Crash"])
      expect(rows(source: "BACKEND").pluck("title")).to eq(["Slow query"])
      expect(rows(source: "FRONTEND").pluck("source")).to eq(["FRONTEND"])
    end

    it "includes a screenshot URL without a query per finding" do
      run = finished_run
      2.times do |index|
        create(:finding, run:, title: "F#{index}").screenshot.attach(
          io: file_fixture("screenshot.png").open, filename: "s.png", content_type: "image/png"
        )
      end

      result = execute_graphql("query($id: ID!) { allFindings(projectId: $id) { allData { screenshotUrl } } }",
                               variables: { id: project.id.to_s }, as: user)

      expect(result.dig("data", "allFindings", "allData").pluck("screenshotUrl")).to all(be_present)
    end

    it "answers not found to an outsider" do
      result = execute_graphql(query, variables: { id: project.id.to_s }, as: create(:user))

      expect(error_codes(result)).to eq(["NOT_FOUND"])
    end
  end

  describe "fetchFindingsSummary" do
    let(:query) do
      "query($id: ID!) { fetchFindingsSummary(projectId: $id) { total resolved totalFindings postedToClickUp " \
        "pendingClickUp bySeverity { severity count } } }"
    end

    def summary
      execute_graphql(query, variables: { id: project.id.to_s }, as: user).dig("data", "fetchFindingsSummary")
    end

    it "counts each open issue once, not every finding from every run" do
      first = finished_run
      latest = finished_run
      create(:finding, run: first, title: "Crash", fingerprint: "crash", severity: :critical)
      create(:finding, run: latest, title: "Crash", fingerprint: "crash", severity: :critical)
      create(:finding, run: first, title: "Fixed", fingerprint: "fixed", severity: :high)

      expect(summary).to include("total" => 1, "resolved" => 1, "totalFindings" => 3)
      expect(summary["bySeverity"].to_h { [it["severity"], it["count"]] }).to include("CRITICAL" => 1, "HIGH" => 0)
    end

    it "breaks open issues down by severity and ClickUp posting" do
      run = finished_run
      create(:finding, run:, title: "A", severity: :high, clickup_task_id: "task-1")
      create(:finding, run:, title: "B", severity: :high)
      create(:finding, run:, title: "C", severity: :low)

      expect(summary).to include("total" => 3, "postedToClickUp" => 1, "pendingClickUp" => 2)
      expect(summary["bySeverity"].to_h { [it["severity"], it["count"]] })
        .to eq("LOW" => 1, "MEDIUM" => 0, "HIGH" => 2, "CRITICAL" => 0)
    end

    it "is all zeros for a project with no findings" do
      expect(summary).to include("total" => 0, "resolved" => 0, "totalFindings" => 0, "postedToClickUp" => 0)
    end

    it "answers not found to an outsider" do
      result = execute_graphql(query, variables: { id: project.id.to_s }, as: create(:user))

      expect(error_codes(result)).to eq(["NOT_FOUND"])
    end
  end
end

require "rails_helper"

# The agent worker (qa-agent-worker) calls these three operations. Their names, input types and
# selections are frozen: see docs/agent-contract.md. The documents below are the worker's own,
# copied from its backend client.
RSpec.describe "Agent contract", type: :graphql do
  let(:project) { create(:project) }
  let(:feature) { create(:scope_feature, :approved, project:) }
  let(:run) { create(:run, :running, project:, scope_feature: feature, role_name: "admin") }
  let(:user) { create(:user, :super_admin) }

  let(:resolve_credential) { "query ResolveRoleCredential($token: String!) { resolveRoleCredential(token: $token) }" }
  let(:create_finding) do
    <<~GQL
      mutation CreateFinding($input: CreateFindingInput!) { createFinding(input: $input) { finding { id } } }
    GQL
  end
  let(:receive_run_result) do
    <<~GQL
      mutation ReceiveRunResult($input: ReceiveResultInput!) {
        receiveRunResult(input: $input) { run { id status } }
      }
    GQL
  end

  def finding_input
    { runId: run.id.to_s, title: "Checkout button unresponsive", reproSteps: ["Open /checkout", "Click Pay"],
      severity: "HIGH", category: "error", details: { type: "uncaught_exception" }, fingerprint: "js:checkout",
      screenshot: nil }
  end

  describe "resolveRoleCredential" do
    let(:token) { RoleCredentials::IssueFetchToken.call(run:).value }

    before { create(:role_credential, project:, role_name: "admin", encrypted_credential_ref: "s3cr3t") }

    it "hands the credential to the agent" do
      result = execute_graphql(resolve_credential, variables: { token: }, agent: true)

      expect(result.dig("data", "resolveRoleCredential")).to eq("s3cr3t")
    end

    it "refuses everyone but the agent, including a super admin's session" do
      expect(error_codes(execute_graphql(resolve_credential, variables: { token: }))).to eq(["UNAUTHENTICATED"])
      expect(error_codes(execute_graphql(resolve_credential, variables: { token: }, as: user)))
        .to eq(["UNAUTHENTICATED"])
    end

    it "refuses a run that is no longer active" do
      token
      run.update!(status: :completed)

      result = execute_graphql(resolve_credential, variables: { token: }, agent: true)

      expect(error_codes(result)).to eq(["RUN_NOT_ACTIVE"])
    end

    it "refuses a forged token" do
      result = execute_graphql(resolve_credential, variables: { token: "#{token}x" }, agent: true)

      expect(error_codes(result)).to eq(["INVALID_TOKEN"])
    end
  end

  describe "createFinding" do
    it "records a finding and returns its id" do
      result = nil

      expect { result = execute_graphql(create_finding, variables: { input: finding_input }, agent: true) }
        .to have_enqueued_job(ClickUpPostJob)

      id = result.dig("data", "createFinding", "finding", "id")
      expect(Finding.find(id)).to have_attributes(title: "Checkout button unresponsive", severity: "high",
                                                  category: "error", fingerprint: "js:checkout", source: "frontend")
    end

    it "takes a screenshot as a multipart upload" do
      input = finding_input.merge(screenshot: graphql_upload("screenshot.png", "image/png"))

      result = execute_graphql(create_finding, variables: { input: }, agent: true)

      expect(Finding.find(result.dig("data", "createFinding", "finding", "id")).screenshot).to be_attached
    end

    it "refuses everyone but the agent" do
      expect(error_codes(execute_graphql(create_finding,
                                         variables: { input: finding_input }))).to eq(["UNAUTHENTICATED"])
      expect(error_codes(execute_graphql(create_finding, variables: { input: finding_input }, as: user)))
        .to eq(["UNAUTHENTICATED"])
      expect(Finding.count).to eq(0)
    end

    it "rejects a duplicate title in the same run" do
      create(:finding, run:, title: finding_input[:title])

      result = execute_graphql(create_finding, variables: { input: finding_input }, agent: true)

      expect(error_codes(result)).to eq(["VALIDATION_FAILED"])
    end

    it "answers not found for an unknown run" do
      result = execute_graphql(create_finding, variables: { input: finding_input.merge(runId: "0") }, agent: true)

      expect(error_codes(result)).to eq(["NOT_FOUND"])
    end
  end

  describe "receiveRunResult" do
    def report(status: "COMPLETED", **extra)
      execute_graphql(receive_run_result, variables: { input: { runId: run.id.to_s, status:, **extra } }, agent: true)
    end

    it "records the audit trail and the final status" do
      result = report(auditLogEntries: [{ actionTaken: "clicked", targetElement: "#pay-button" }],
                      networkLog: [{ url: "/graphql" }], summary: { pages: 2 })

      expect(result.dig("data", "receiveRunResult", "run")).to eq("id" => run.id.to_s, "status" => "COMPLETED")
      expect(run.reload).to have_attributes(network_log: [{ "url" => "/graphql" }], summary: { "pages" => 2 })
      expect(run.audit_log_entries.pluck(:action_taken, :target_element)).to eq([["clicked", "#pay-button"]])
    end

    it "accepts FAILED and BLOCKED, and nothing else" do
      expect(report(status: "FAILED").dig("data", "receiveRunResult", "run", "status")).to eq("FAILED")
      expect(report(status: "RUNNING")["errors"].first["message"]).to include("COMPLETED, FAILED, BLOCKED")
    end

    it "is safe to repeat" do
      report(auditLogEntries: [{ actionTaken: "clicked" }])

      expect(report(auditLogEntries: [{ actionTaken: "clicked" }])["errors"]).to be_nil
      expect(run.reload.audit_log_entries.count).to eq(1)
    end

    it "refuses everyone but the agent" do
      result = execute_graphql(receive_run_result, variables: { input: { runId: run.id.to_s, status: "COMPLETED" } },
                                                   as: user)

      expect(error_codes(result)).to eq(["UNAUTHENTICATED"])
      expect(run.reload).to be_running
    end

    it "reports a run that can't take that status" do
      run.update!(status: :completed)

      expect(error_codes(report(status: "FAILED"))).to eq(["INVALID_RUN_TRANSITION"])
    end
  end
end

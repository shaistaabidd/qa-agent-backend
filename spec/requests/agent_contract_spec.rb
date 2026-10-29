require "rails_helper"

# The same calls as graphql/agent_contract_spec.rb, over HTTP exactly as the worker sends them:
# the X-Agent-Token header (and no user token), JSON bodies, and the multipart upload format.
RSpec.describe "Agent contract over HTTP" do
  let(:project) { create(:project) }
  let(:run) { create(:run, :running, project:, scope_feature: create(:scope_feature, :approved, project:)) }
  let(:agent_headers) { { "X-Agent-Token" => "agent-api-token" } }

  def graphql(query, variables, headers: agent_headers)
    post "/graphql", params: { query:, variables: }.to_json,
                     headers: headers.merge("CONTENT_TYPE" => "application/json")
    response.parsed_body
  end

  it "resolves a credential for the agent token and refuses a wrong one" do
    create(:role_credential, project:, role_name: run.role_name, encrypted_credential_ref: "s3cr3t")
    token = RoleCredentials::IssueFetchToken.call(run:).value
    query = "query ResolveRoleCredential($token: String!) { resolveRoleCredential(token: $token) }"

    expect(graphql(query, { token: }).dig("data", "resolveRoleCredential")).to eq("s3cr3t")

    wrong = graphql(query, { token: }, headers: { "X-Agent-Token" => "agent-api-tokeN" })
    expect(wrong.dig("errors", 0, "extensions", "code")).to eq("UNAUTHENTICATED")
    expect(graphql(query, { token: }, headers: {}).dig("errors", 0, "extensions", "code")).to eq("UNAUTHENTICATED")
  end

  it "refuses the agent operations when no agent token is configured at all" do
    allow(Rails.configuration.x).to receive(:agent).and_return(api_token: nil)

    result = graphql("mutation($input: ReceiveResultInput!) { receiveRunResult(input: $input) { run { id } } }",
                     { input: { runId: run.id.to_s, status: "COMPLETED" } }, headers: { "X-Agent-Token" => "" })

    expect(result.dig("errors", 0, "extensions", "code")).to eq("UNAUTHENTICATED")
  end

  it "creates a finding from the worker's multipart request, screenshot included" do
    query = <<~GQL
      mutation CreateFinding($input: CreateFindingInput!) { createFinding(input: $input) { finding { id } } }
    GQL
    input = { runId: run.id.to_s, title: "Crash", reproSteps: [], severity: "HIGH", category: nil, details: nil,
              fingerprint: nil, screenshot: nil }

    post "/graphql",
         params: { operations: { query:, variables: { input: } }.to_json,
                   map: { "0" => ["variables.input.screenshot"] }.to_json,
                   "0" => fixture_file_upload("screenshot.png", "image/png") },
         headers: agent_headers

    finding = Finding.find(response.parsed_body.dig("data", "createFinding", "finding", "id"))
    expect(finding.screenshot).to be_attached
  end

  it "reports a run's result" do
    query = <<~GQL
      mutation ReceiveRunResult($input: ReceiveResultInput!) {
        receiveRunResult(input: $input) { run { id status } }
      }
    GQL

    result = graphql(query, { input: { runId: run.id.to_s, status: "COMPLETED", auditLogEntries: [], networkLog: [],
                                       summary: {} } })

    expect(result.dig("data", "receiveRunResult", "run", "status")).to eq("COMPLETED")
  end
end

require 'rails_helper'

RSpec.describe 'GraphQL: run dispatch and agent callbacks', type: :request do
  def graphql(query, variables: {}, token: nil, agent_token: nil)
    headers = { 'CONTENT_TYPE' => 'application/json' }
    headers['Authorization'] = "Bearer #{token}" if token
    headers['X-Agent-Token'] = agent_token if agent_token

    post '/graphql', params: { query: query, variables: variables }.to_json, headers: headers
    response.parsed_body
  end

  let!(:admin) { create(:user) }
  let!(:project) { create(:project) }
  let!(:scope_feature) { create(:scope_feature, project: project, approved: true) }
  let(:admin_token) { Users::GenerateToken.call!(user: admin).token }

  before do
    create(:membership, user: admin, project: project, role: :admin)
    create(:role_credential, project: project, role_name: 'admin', encrypted_credential_ref: 's3cr3t')

    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('AGENT_API_TOKEN', nil).and_return('agent-shared-secret')
  end

  describe 'dispatchRun' do
    it 'enqueues a RunDispatchJob for an approved scope feature with a configured credential' do
      expect do
        result = graphql(<<~GQL, token: admin_token)
          mutation {
            dispatchRun(input: { scopeFeatureId: "#{scope_feature.id}", roleName: "admin" }) {
              run { status roleName }
            }
          }
        GQL

        expect(result.dig('data', 'dispatchRun', 'run', 'status')).to eq('QUEUED')
      end.to have_enqueued_job(RunDispatchJob)
    end

    it 'rejects a non-admin, and rejects a missing credential, distinctly' do
      member = create(:user)
      create(:membership, user: member, project: project, role: :member)

      result = graphql(
        "mutation { dispatchRun(input: { scopeFeatureId: \"#{scope_feature.id}\", " \
        'roleName: "admin" }) { run { id } } }',
        token: Users::GenerateToken.call!(user: member).token
      )
      expect(result.dig('errors', 0, 'code')).to eq(403)

      result = graphql(
        "mutation { dispatchRun(input: { scopeFeatureId: \"#{scope_feature.id}\", " \
        'roleName: "billing" }) { run { id } } }',
        token: admin_token
      )
      expect(result.dig('errors', 0, 'message')).to match(/no credential configured/i)
    end
  end

  describe 'resolveRoleCredential and receiveRunResult (the agent-facing surface)' do
    let(:run) { create(:run, project: project, scope_feature: scope_feature, role_name: 'admin', status: :running) }
    let(:fetch_token) { RoleCredentials::IssueFetchToken.call!(run: run).token }

    it 'requires the shared agent token, not a user JWT, for resolveRoleCredential' do
      result = graphql("query { resolveRoleCredential(token: \"#{fetch_token}\") }", token: admin_token)
      expect(result.dig('errors', 0, 'code')).to eq(401)

      result = graphql("query { resolveRoleCredential(token: \"#{fetch_token}\") }", agent_token: 'agent-shared-secret')
      expect(result.dig('data', 'resolveRoleCredential')).to eq('s3cr3t')
    end

    it "refuses to resolve a credential for a run that isn't active" do
      run.update!(status: :completed)

      result = graphql("query { resolveRoleCredential(token: \"#{fetch_token}\") }", agent_token: 'agent-shared-secret')

      expect(result.dig('errors', 0, 'code')).to eq(422)
    end

    it 'lets the agent report a completed run with audit log entries' do
      result = graphql(<<~GQL, agent_token: 'agent-shared-secret')
        mutation {
          receiveRunResult(input: {
            runId: "#{run.id}",
            status: COMPLETED,
            auditLogEntries: [{ actionTaken: "clicked", targetElement: "#pay-button" }]
          }) {
            run { status }
          }
        }
      GQL

      expect(result.dig('data', 'receiveRunResult', 'run', 'status')).to eq('COMPLETED')
      expect(run.reload.audit_log_entries.count).to eq(1)
    end

    it 'rejects receiveRunResult without the agent token' do
      result = graphql(
        "mutation { receiveRunResult(input: { runId: \"#{run.id}\", status: COMPLETED }) { run { id } } }",
        token: admin_token
      )

      expect(result.dig('errors', 0, 'code')).to eq(401)
    end
  end
end

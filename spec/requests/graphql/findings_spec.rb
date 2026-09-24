require 'rails_helper'

RSpec.describe 'GraphQL: findings and ClickUp connection', type: :request do
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
  let!(:run) { create(:run, project: project, scope_feature: scope_feature, status: :running) }
  let(:admin_token) { Users::GenerateToken.call!(user: admin).token }

  before do
    create(:membership, user: admin, project: project, role: :admin)

    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('AGENT_API_TOKEN', nil).and_return('agent-shared-secret')
  end

  describe 'createFinding' do
    it 'requires the agent token, not a user JWT' do
      result = graphql(
        "mutation { createFinding(input: { runId: \"#{run.id}\", title: \"Bug\", " \
        'reproSteps: ["step 1"], severity: HIGH }) { finding { id } } }',
        token: admin_token
      )
      expect(result.dig('errors', 0, 'code')).to eq(401)
    end

    it 'creates a finding via multipart upload with a screenshot and enqueues ClickUpPostJob' do
      query = <<~GQL
        mutation($file: Upload) {
          createFinding(input: {
            runId: "#{run.id}",
            title: "Checkout button unresponsive",
            reproSteps: ["Open /checkout", "Click Pay"],
            severity: HIGH,
            screenshot: $file
          }) {
            finding { id title severity screenshotUrl }
          }
        }
      GQL

      operations = { query: query, variables: { file: nil } }.to_json
      map = { '0' => ['variables.file'] }.to_json
      file = fixture_file_upload('screenshot.png', 'image/png')

      expect do
        post '/graphql',
             params: { operations: operations, map: map, '0' => file },
             headers: { 'X-Agent-Token' => 'agent-shared-secret' }
      end.to have_enqueued_job(ClickUpPostJob)

      result = response.parsed_body
      finding_data = result.dig('data', 'createFinding', 'finding')
      expect(finding_data['title']).to eq('Checkout button unresponsive')
      expect(finding_data['severity']).to eq('HIGH')
      expect(finding_data['screenshotUrl']).to be_present

      expect(Finding.last.screenshot).to be_attached
    end

    it 'rejects a duplicate title for the same run with a clear error' do
      create(:finding, run: run, title: 'Checkout button unresponsive')

      result = graphql(
        "mutation { createFinding(input: { runId: \"#{run.id}\", title: \"Checkout button unresponsive\", " \
        'reproSteps: [], severity: HIGH }) { finding { id } } }',
        agent_token: 'agent-shared-secret'
      )

      expect(result.dig('errors', 0, 'message')).to match(/title/i)
    end
  end

  describe 'connectClickUp' do
    it 'lets a project admin connect a ClickUp list' do
      result = graphql(
        "mutation { connectClickUp(input: { projectId: \"#{project.id}\", listId: \"900\" }) { project { id } } }",
        token: admin_token
      )

      expect(result['errors']).to be_nil
      expect(project.integrations.find_by(integration_type: :click_up).external_account_id).to eq('900')
    end

    it 'forbids a non-admin member with a 403' do
      member = create(:user)
      create(:membership, user: member, project: project, role: :member)

      result = graphql(
        "mutation { connectClickUp(input: { projectId: \"#{project.id}\", listId: \"900\" }) { project { id } } }",
        token: Users::GenerateToken.call!(user: member).token
      )

      expect(result.dig('errors', 0, 'code')).to eq(403)
    end
  end

  describe 'findingsForProject' do
    it "lists findings across the project's runs for a member" do
      create(:finding, run: run, title: 'Checkout button unresponsive')

      result = graphql(
        "query { findingsForProject(projectId: \"#{project.id}\") { allData { title } totalPages } }",
        token: admin_token
      )

      titles = result.dig('data', 'findingsForProject', 'allData').pluck('title')
      expect(titles).to include('Checkout button unresponsive')
    end
  end
end

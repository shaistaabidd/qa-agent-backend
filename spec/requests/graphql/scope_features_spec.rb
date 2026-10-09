require 'rails_helper'

RSpec.describe 'GraphQL: GitHub connection and scope features', type: :request do
  def graphql(query, variables: {}, token: nil)
    headers = { 'CONTENT_TYPE' => 'application/json' }
    headers['Authorization'] = "Bearer #{token}" if token

    post '/graphql', params: { query: query, variables: variables }.to_json, headers: headers
    response.parsed_body
  end

  let!(:admin) { create(:user) }
  let!(:member) { create(:user) }
  let!(:project) { create(:project) }
  let(:admin_token) { Users::GenerateToken.call!(user: admin).token }
  let(:member_token) { Users::GenerateToken.call!(user: member).token }

  before do
    create(:membership, user: admin, project: project, role: :admin)
    create(:membership, user: member, project: project, role: :member)
  end

  describe 'connectGithub' do
    let(:github_service) { instance_double(GitHubAppService, repository_names: ['acme/checkout-app']) }

    before do
      create(:integration, project: project, external_account_id: '999', repo_full_name: nil)
      allow(GitHubAppService).to receive(:for_installation).with('999').and_return(github_service)
    end

    it 'lets a project admin connect a repo from the installation' do
      result = graphql(<<~GQL, token: admin_token)
        mutation {
          connectGithub(input: { projectId: "#{project.id}", repoFullName: "acme/checkout-app" }) {
            project { repoConnected repoFullName }
          }
        }
      GQL

      expect(result.dig('data', 'connectGithub', 'project')).to eq(
        'repoConnected' => true, 'repoFullName' => 'acme/checkout-app'
      )
    end

    it 'forbids a non-admin member with a 403' do
      result = graphql(<<~GQL, token: member_token)
        mutation {
          connectGithub(input: { projectId: "#{project.id}", repoFullName: "acme/checkout-app" }) {
            project { id }
          }
        }
      GQL

      expect(result.dig('errors', 0, 'code')).to eq(403)
    end
  end

  describe 'githubInstallUrl' do
    before { allow(ENV).to receive(:fetch).and_call_original }

    it 'returns the GitHub App install URL with a signed state for the admin' do
      allow(ENV).to receive(:fetch).with('GITHUB_APP_SLUG', nil).and_return('qa-agent')

      result = graphql("{ githubInstallUrl(projectId: \"#{project.id}\") }", token: admin_token)

      url = URI.parse(result.dig('data', 'githubInstallUrl'))
      expect(url.to_s).to start_with('https://github.com/apps/qa-agent/installations/new')
      state = Rack::Utils.parse_query(url.query)['state']
      expect(GitHubInstallState.verify(state)).to eq('project_id' => project.id, 'user_id' => admin.id)
    end

    it 'forbids a non-admin member' do
      result = graphql("{ githubInstallUrl(projectId: \"#{project.id}\") }", token: member_token)

      expect(result.dig('errors', 0, 'code')).to eq(403)
    end
  end

  describe 'scanCodebase' do
    it 'rejects scanning before a repo is connected' do
      result = graphql(
        "mutation { scanCodebase(input: { projectId: \"#{project.id}\" }) { success message } }",
        token: admin_token
      )

      expect(result.dig('data', 'scanCodebase')).to be_nil
      expect(result.dig('errors', 0, 'message')).to match(/connect a github repository/i)
    end

    it 'enqueues a RepoScanJob once a repo is connected' do
      create(:integration, project: project, integration_type: :github, external_account_id: '999',
                           repo_full_name: 'acme/checkout-app')
      project.update!(repo_connection: project.integrations.find_by(integration_type: :github))

      expect do
        graphql(
          "mutation { scanCodebase(input: { projectId: \"#{project.id}\" }) { success message } }",
          token: admin_token
        )
      end.to have_enqueued_job(RepoScanJob).with(project.id)
    end
  end

  describe 'approveScopeFeature' do
    it 'approves a scope feature for a project admin' do
      scope_feature = create(:scope_feature, project: project, approved: false)

      result = graphql(
        "mutation { approveScopeFeature(input: { id: \"#{scope_feature.id}\" }) { scopeFeature { approved } } }",
        token: admin_token
      )

      expect(result.dig('data', 'approveScopeFeature', 'scopeFeature', 'approved')).to be true
    end
  end

  describe 'scopeFeaturesForProject' do
    it 'lists scope features for a project member' do
      create(:scope_feature, project: project, name: 'Checkout flow')

      result = graphql(
        "query { scopeFeaturesForProject(projectId: \"#{project.id}\") { allData { name } totalPages } }",
        token: member_token
      )

      names = result.dig('data', 'scopeFeaturesForProject', 'allData').pluck('name')
      expect(names).to include('Checkout flow')
    end

    it 'forbids an outsider with a 403' do
      outsider_token = Users::GenerateToken.call!(user: create(:user)).token

      result = graphql(
        "query { scopeFeaturesForProject(projectId: \"#{project.id}\") { allData { name } } }",
        token: outsider_token
      )

      expect(result.dig('errors', 0, 'code')).to eq(403)
    end
  end
end

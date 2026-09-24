require 'rails_helper'

RSpec.describe 'GraphQL: auth and projects', type: :request do
  def graphql(query, variables: {}, token: nil)
    headers = { 'CONTENT_TYPE' => 'application/json' }
    headers['Authorization'] = "Bearer #{token}" if token

    post '/graphql', params: { query: query, variables: variables }.to_json, headers: headers
    response.parsed_body
  end

  describe 'registerUser' do
    it 'creates a user and returns a valid token' do
      result = graphql(<<~GQL)
        mutation {
          registerUser(input: { email: "shaista@staunch.co", password: "password123" }) {
            token
            user { email }
          }
        }
      GQL

      expect(result.dig('data', 'registerUser', 'user', 'email')).to eq('shaista@staunch.co')
      expect(result.dig('data', 'registerUser', 'token')).to be_present
    end
  end

  describe 'loginUser' do
    let!(:user) { create(:user, email: 'shaista@staunch.co', password: 'password123') }

    it 'rejects the wrong password with a 401' do
      result = graphql(<<~GQL)
        mutation {
          loginUser(input: { email: "shaista@staunch.co", password: "wrong" }) { token }
        }
      GQL

      expect(result.dig('errors', 0, 'code')).to eq(401)
    end

    it 'returns a token that authenticates subsequent requests' do
      login_result = graphql(<<~GQL)
        mutation {
          loginUser(input: { email: "shaista@staunch.co", password: "password123" }) { token }
        }
      GQL
      token = login_result.dig('data', 'loginUser', 'token')

      me_result = graphql('{ me { email } }', token: token)

      expect(me_result.dig('data', 'me', 'email')).to eq('shaista@staunch.co')
    end
  end

  describe 'project access' do
    let!(:owner) { create(:user) }
    let!(:outsider) { create(:user) }
    let!(:project) { create(:project) }

    before { create(:membership, user: owner, project: project, role: :admin) }

    def token_for(user)
      Users::GenerateToken.call!(user: user).token
    end

    it 'lets a project member fetch it' do
      result = graphql(
        'query($id: ID!) { fetchProject(id: $id) { name } }',
        variables: { 'id' => project.id.to_s },
        token: token_for(owner)
      )

      expect(result.dig('data', 'fetchProject', 'name')).to eq(project.name)
    end

    it 'forbids a non-member with a 403' do
      result = graphql(
        'query($id: ID!) { fetchProject(id: $id) { name } }',
        variables: { 'id' => project.id.to_s },
        token: token_for(outsider)
      )

      expect(result.dig('errors', 0, 'code')).to eq(403)
    end

    it 'rejects unauthenticated requests with a 401' do
      result = graphql('{ me { email } }')

      expect(result.dig('errors', 0, 'code')).to eq(401)
    end
  end

  describe 'createProject' do
    let!(:user) { create(:user) }

    it 'makes the creator an admin member' do
      result = graphql(<<~GQL, token: Users::GenerateToken.call!(user: user).token)
        mutation {
          createProject(input: { name: "Demo", targetUrl: "https://staging.example.com" }) {
            project { id }
          }
        }
      GQL

      project_id = result.dig('data', 'createProject', 'project', 'id')
      expect(Membership.find_by(project_id: project_id, user_id: user.id)).to be_admin
    end
  end
end

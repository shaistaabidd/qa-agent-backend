require 'rails_helper'

RSpec.describe 'GraphQL: role credentials', type: :request do
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

  describe 'setRoleCredential' do
    it 'lets a project admin configure a credential, never returning the raw value' do
      result = graphql(
        "mutation { setRoleCredential(input: { projectId: \"#{project.id}\", roleName: \"admin\", " \
        'credentialValue: "s3cr3t" }) { roleCredential { roleName } } }',
        token: admin_token
      )

      expect(result.dig('data', 'setRoleCredential', 'roleCredential', 'roleName')).to eq('admin')
      expect(result.to_s).not_to include('s3cr3t')
    end

    it 'forbids a non-admin member with a 403' do
      result = graphql(
        "mutation { setRoleCredential(input: { projectId: \"#{project.id}\", roleName: \"admin\", " \
        'credentialValue: "s3cr3t" }) { roleCredential { roleName } } }',
        token: member_token
      )

      expect(result.dig('errors', 0, 'code')).to eq(403)
    end
  end

  describe 'roleCredentialsForProject' do
    it 'lists configured role names for any project member, without the credential value' do
      create(:role_credential, project: project, role_name: 'admin', encrypted_credential_ref: 's3cr3t')

      result = graphql(
        "query { roleCredentialsForProject(projectId: \"#{project.id}\") { roleName } }",
        token: member_token
      )

      role_names = result.dig('data', 'roleCredentialsForProject').pluck('roleName')
      expect(role_names).to eq(['admin'])
      expect(result.to_s).not_to include('s3cr3t')
    end
  end
end

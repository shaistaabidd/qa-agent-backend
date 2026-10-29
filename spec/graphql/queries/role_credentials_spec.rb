require "rails_helper"

RSpec.describe "Role credential queries", type: :graphql do
  let(:user) { create(:user) }
  let(:project) { create(:project) }

  before { create(:membership, user:, project:) }

  it "lists the configured roles for any member, never the credential value" do
    create(:role_credential, project:, role_name: "admin", encrypted_credential_ref: "s3cr3t")
    create(:role_credential, project:, role_name: "buyer")

    result = execute_graphql("query($id: ID!) { allRoleCredentials(projectId: $id) { roleName } }",
                             variables: { id: project.id.to_s }, as: user)

    expect(result.dig("data", "allRoleCredentials").pluck("roleName")).to eq(%w[admin buyer])
    expect(result.to_s).not_to include("s3cr3t")
  end

  it "has no field that could return the value" do
    result = execute_graphql("{ allRoleCredentials(projectId: \"#{project.id}\") { encryptedCredentialRef } }",
                             as: user)

    expect(result["errors"].first["message"]).to include("doesn't exist on type 'RoleCredential'")
  end
end

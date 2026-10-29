require "rails_helper"

RSpec.describe "setRoleCredential", type: :graphql do
  let(:admin) { create(:user) }
  let(:member) { create(:user) }
  let(:project) { create(:project) }
  let(:mutation) do
    <<~GQL
      mutation($input: SetRoleCredentialInput!) { setRoleCredential(input: $input) { roleCredential { roleName } } }
    GQL
  end
  let(:input) { { projectId: project.id.to_s, roleName: "admin", credentialValue: "s3cr3t" } }

  before do
    create(:membership, :admin, user: admin, project:)
    create(:membership, user: member, project:)
  end

  it "stores the credential encrypted and never returns the value" do
    result = execute_graphql(mutation, variables: { input: }, as: admin)

    expect(result.dig("data", "setRoleCredential", "roleCredential", "roleName")).to eq("admin")
    expect(result.to_s).not_to include("s3cr3t")
    expect(project.role_credentials.sole.encrypted_credential_ref).to eq("s3cr3t")
  end

  it "replaces the credential for a role" do
    execute_graphql(mutation, variables: { input: }, as: admin)

    expect { execute_graphql(mutation, variables: { input: input.merge(credentialValue: "new") }, as: admin) }
      .not_to change(RoleCredential, :count)
    expect(project.role_credentials.sole.encrypted_credential_ref).to eq("new")
  end

  it "is forbidden to a plain member" do
    expect(error_codes(execute_graphql(mutation, variables: { input: }, as: member))).to eq(["FORBIDDEN"])
    expect(RoleCredential.count).to eq(0)
  end
end

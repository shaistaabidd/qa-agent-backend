require "rails_helper"

RSpec.describe "Archiving and access control", type: :graphql do
  let(:admin) { create(:user, :super_admin) }
  let(:target) { create(:user) }

  let(:archive_mutation) do
    <<~GQL
      mutation($id: ID!, $archived: Boolean!) {
        archiveUser(input: { id: $id, archived: $archived }) { user { archived } }
      }
    GQL
  end
  let(:access_mutation) do
    <<~GQL
      mutation($id: ID!, $accessRevoked: Boolean!) {
        updateUserAccess(input: { id: $id, accessRevoked: $accessRevoked }) { user { accessRevoked } }
      }
    GQL
  end

  it "archives a user and ends their sessions" do
    create(:session, user: target)

    result = execute_graphql(archive_mutation, variables: { id: target.id, archived: true }, as: admin)

    expect(result.dig("data", "archiveUser", "user", "archived")).to be(true)
    expect(target.sessions.count).to eq(0)
  end

  it "restores an archived user" do
    target.archive!

    execute_graphql(archive_mutation, variables: { id: target.id, archived: false }, as: admin)

    expect(target.reload).not_to be_archived
  end

  it "revokes and restores access" do
    execute_graphql(access_mutation, variables: { id: target.id, accessRevoked: true }, as: admin)
    expect(target.reload).to be_access_revoked

    execute_graphql(access_mutation, variables: { id: target.id, accessRevoked: false }, as: admin)
    expect(target.reload).not_to be_access_revoked
  end

  it "does not let an admin lock themselves out" do
    result = execute_graphql(access_mutation, variables: { id: admin.id, accessRevoked: true }, as: admin)

    expect(error_codes(result)).to eq(["FORBIDDEN"])
  end

  it "hides the target from a regular user" do
    result = execute_graphql(archive_mutation, variables: { id: target.id, archived: true }, as: create(:user))

    expect(error_codes(result)).to eq(["NOT_FOUND"])
  end
end

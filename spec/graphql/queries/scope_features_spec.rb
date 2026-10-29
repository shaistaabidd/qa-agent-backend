require "rails_helper"

RSpec.describe "Scope feature queries", type: :graphql do
  let(:user) { create(:user) }
  let(:project) { create(:project) }
  let(:query) do
    "query($id: ID!) { allScopeFeatures(projectId: $id) { count allData { name approved } } }"
  end

  it "lists a project's scope features for a member" do
    create(:membership, user:, project:)
    create(:scope_feature, project:, name: "Checkout flow")
    create(:scope_feature, name: "Other project's feature")

    result = execute_graphql(query, variables: { id: project.id.to_s }, as: user)

    expect(result.dig("data", "allScopeFeatures", "allData")).to eq([{ "name" => "Checkout flow",
                                                                       "approved" => false }])
  end

  it "answers not found to an outsider" do
    expect(error_codes(execute_graphql(query, variables: { id: project.id.to_s }, as: user))).to eq(["NOT_FOUND"])
  end
end

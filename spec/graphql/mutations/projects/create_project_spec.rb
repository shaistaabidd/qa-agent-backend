require "rails_helper"

RSpec.describe "createProject", type: :graphql do
  let(:user) { create(:user) }
  let(:mutation) do
    <<~GQL
      mutation($input: CreateProjectInput!) {
        createProject(input: $input) { project { id name myRole } }
      }
    GQL
  end

  def create_project(as: user, **input) = execute_graphql(mutation, variables: { input: }, as:)

  it "creates the project and makes the creator its admin" do
    result = create_project(name: "Demo", targetUrl: "https://staging.example.com")

    project = result.dig("data", "createProject", "project")
    expect(project).to include("name" => "Demo", "myRole" => "ADMIN")
    expect(Membership.find_by(project_id: project["id"], user_id: user.id)).to be_admin
  end

  it "rejects an invalid project with the validation error" do
    result = create_project(name: "", targetUrl: "not a url")

    expect(error_codes(result)).to eq(["VALIDATION_FAILED"])
    expect(Project.count).to eq(0)
  end

  it "requires sign-in" do
    result = execute_graphql(mutation, variables: { input: { name: "Demo", targetUrl: "https://a.example.com" } })

    expect(error_codes(result)).to eq(["UNAUTHENTICATED"])
  end

  it "rate limits project creation per user" do
    30.times { create_project(name: "Demo", targetUrl: "https://a.example.com") }

    expect(error_codes(create_project(name: "One too many", targetUrl: "https://a.example.com")))
      .to eq(["RATE_LIMITED"])
    expect(error_codes(create_project(as: create(:user), name: "Other user", targetUrl: "https://a.example.com")))
      .to eq([])
  end
end

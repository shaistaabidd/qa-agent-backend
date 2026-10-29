require "rails_helper"

RSpec.describe Projects::Create do
  let(:user) { create(:user) }

  it "creates the project and makes the creator its admin" do
    result = described_class.call(user:, name: "Shop", target_url: "https://shop.example.com")

    expect(result).to be_success
    project = result.value
    expect(project).to have_attributes(name: "Shop", target_url: "https://shop.example.com")
    expect(project.memberships.sole).to have_attributes(user:, role: "admin")
  end

  it "fails with the validation message, and creates nothing, for an invalid project" do
    result = described_class.call(user:, name: "", target_url: "not a url")

    expect(result).to be_failure
    expect(result.error.code).to eq(:validation_failed)
    expect(Project.count).to eq(0)
    expect(Membership.count).to eq(0)
  end
end

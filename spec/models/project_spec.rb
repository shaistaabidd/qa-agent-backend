require "rails_helper"

RSpec.describe Project do
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:target_url) }
  it { is_expected.to have_many(:memberships).dependent(:destroy) }
  it { is_expected.to have_many(:users).through(:memberships) }
  it { is_expected.to have_many(:scope_features).dependent(:destroy) }
  it { is_expected.to have_many(:runs).dependent(:destroy) }
  it { is_expected.to belong_to(:repo_connection).class_name("Integration").optional }

  describe "target_url" do
    it "accepts http and https addresses" do
      expect(build(:project, target_url: "http://localhost:3000")).to be_valid
      expect(build(:project, target_url: "https://app.example.com/start")).to be_valid
    end

    it "rejects anything else" do
      ["ftp://example.com", "javascript:alert(1)", "not a url", "https://"].each do |url|
        expect(build(:project, target_url: url)).not_to be_valid, url
      end
    end
  end

  it "can be destroyed with a connected repository, though the two tables point at each other" do
    project = create(:project)
    project.update!(repo_connection: create(:integration, project:))

    expect { project.destroy! }.not_to raise_error
    expect(Integration.count).to eq(0)
  end
end

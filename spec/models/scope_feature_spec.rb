require "rails_helper"

RSpec.describe ScopeFeature do
  it { is_expected.to belong_to(:project) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to have_many(:runs).dependent(:destroy) }

  it "defaults to unapproved" do
    expect(create(:scope_feature)).not_to be_approved
  end
end

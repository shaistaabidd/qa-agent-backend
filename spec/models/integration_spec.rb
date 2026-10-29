require "rails_helper"

RSpec.describe Integration do
  it { is_expected.to belong_to(:project) }
  it { is_expected.to define_enum_for(:integration_type).with_values(github: 0, click_up: 1) }

  it "allows one integration of a type per project" do
    existing = create(:integration)

    expect(build(:integration, project: existing.project)).not_to be_valid
    expect(build(:integration, :click_up, project: existing.project)).to be_valid
  end
end

require "rails_helper"

RSpec.describe ScopeFeatures::Approve do
  it "approves the scope feature" do
    scope_feature = create(:scope_feature)

    result = described_class.call(scope_feature:)

    expect(result).to be_success
    expect(scope_feature.reload).to be_approved
  end
end

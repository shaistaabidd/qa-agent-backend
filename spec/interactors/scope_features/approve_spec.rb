require 'rails_helper'

RSpec.describe ScopeFeatures::Approve do
  it 'marks the scope feature as approved' do
    scope_feature = create(:scope_feature, approved: false)

    result = described_class.call(scope_feature: scope_feature)

    expect(result).to be_success
    expect(scope_feature.reload.approved).to be true
  end
end

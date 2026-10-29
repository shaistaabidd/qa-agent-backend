require "rails_helper"

RSpec.describe Membership do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:project) }
  it { is_expected.to define_enum_for(:role).with_values(member: 0, admin: 1) }

  it "adds a user to a project once" do
    membership = create(:membership)

    expect(build(:membership, user: membership.user, project: membership.project)).not_to be_valid
  end
end

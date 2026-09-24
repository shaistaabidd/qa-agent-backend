require 'rails_helper'

RSpec.describe Membership, type: :model do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:project) }
  it { is_expected.to define_enum_for(:role).with_values(member: 0, admin: 1) }

  it 'prevents the same user from being added to a project twice' do
    membership = create(:membership)
    duplicate = build(:membership, user: membership.user, project: membership.project)

    expect(duplicate).not_to be_valid
  end
end

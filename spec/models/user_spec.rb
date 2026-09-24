require 'rails_helper'

RSpec.describe User, type: :model do
  it { is_expected.to have_many(:memberships).dependent(:destroy) }
  it { is_expected.to have_many(:projects).through(:memberships) }
  it { is_expected.to validate_presence_of(:email) }

  it 'downcases and uniquely indexes email' do
    create(:user, email: 'shaista@staunch.co')
    duplicate = build(:user, email: 'shaista@staunch.co')

    expect(duplicate).not_to be_valid
  end
end

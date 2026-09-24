require 'rails_helper'

RSpec.describe Finding, type: :model do
  it { is_expected.to belong_to(:run) }
  it { is_expected.to validate_presence_of(:title) }
  it { is_expected.to define_enum_for(:severity).with_values(low: 0, medium: 1, high: 2, critical: 3) }

  it 'prevents duplicate findings with the same title on a run' do
    create(:finding, title: 'Checkout button unresponsive')
    run = described_class.last.run
    duplicate = build(:finding, run: run, title: 'Checkout button unresponsive')

    expect(duplicate).not_to be_valid
  end
end

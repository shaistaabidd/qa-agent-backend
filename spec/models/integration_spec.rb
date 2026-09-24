require 'rails_helper'

RSpec.describe Integration, type: :model do
  it { is_expected.to belong_to(:project) }
  it { is_expected.to define_enum_for(:integration_type).with_values(github: 0, click_up: 1) }

  it 'only allows one integration of a given type per project' do
    create(:integration, integration_type: :github)
    project = described_class.last.project
    duplicate = build(:integration, project: project, integration_type: :github)

    expect(duplicate).not_to be_valid
  end
end

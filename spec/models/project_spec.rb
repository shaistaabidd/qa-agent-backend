require 'rails_helper'

RSpec.describe Project, type: :model do
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:target_url) }
  it { is_expected.to have_many(:memberships).dependent(:destroy) }
  it { is_expected.to have_many(:users).through(:memberships) }
  it { is_expected.to have_many(:scope_features).dependent(:destroy) }
  it { is_expected.to have_many(:runs).dependent(:destroy) }
  it { is_expected.to belong_to(:repo_connection).class_name('Integration').optional }

  it 'can be destroyed even with a connected repo_connection (circular FK)' do
    project = create(:project)
    integration = create(:integration, project: project)
    project.update!(repo_connection: integration)

    expect { project.destroy! }.not_to raise_error
  end
end

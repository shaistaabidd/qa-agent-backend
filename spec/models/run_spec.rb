require 'rails_helper'

RSpec.describe Run, type: :model do
  it { is_expected.to belong_to(:project) }
  it { is_expected.to belong_to(:scope_feature) }
  it { is_expected.to validate_presence_of(:role_name) }

  it 'starts queued and records started_at on dispatch' do
    run = create(:run)

    expect(run).to be_queued

    run.dispatch!

    expect(run).to be_running
    expect(run.started_at).to be_present
  end

  it 'records finished_at on completion' do
    run = create(:run, status: :running)

    run.complete!

    expect(run).to be_completed
    expect(run.finished_at).to be_present
  end

  it 'can fail from queued, running, or blocked' do
    run = create(:run, status: :blocked)

    run.fail!

    expect(run).to be_failed
  end

  it 'cannot complete directly from queued' do
    run = create(:run)

    expect { run.complete! }.to raise_error(AASM::InvalidTransition)
  end
end

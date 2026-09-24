require 'rails_helper'

RSpec.describe Runs::Dispatch do
  let(:project) { create(:project) }
  let(:scope_feature) { create(:scope_feature, project: project, approved: true) }

  before { create(:role_credential, project: project, role_name: 'admin') }

  it 'creates a queued Run and enqueues RunDispatchJob' do
    expect do
      result = described_class.call(scope_feature: scope_feature, role_name: 'admin')
      expect(result).to be_success
      expect(result.run).to be_queued
    end.to have_enqueued_job(RunDispatchJob)
  end

  it 'rejects dispatch for an unapproved scope feature' do
    scope_feature.update!(approved: false)

    result = described_class.call(scope_feature: scope_feature, role_name: 'admin')

    expect(result).to be_failure
    expect(result.error).to match(/not approved/i)
  end

  it 'rejects dispatch when no credential exists for the role' do
    result = described_class.call(scope_feature: scope_feature, role_name: 'billing')

    expect(result).to be_failure
    expect(result.error).to match(/no credential configured/i)
  end
end

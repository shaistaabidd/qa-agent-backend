require "rails_helper"

RSpec.describe Runs::Dispatch do
  let(:project) { create(:project) }
  let(:scope_feature) { create(:scope_feature, :approved, project:) }

  before { create(:role_credential, project:, role_name: "admin") }

  it "creates a queued run and enqueues the dispatch job" do
    result = nil

    expect { result = described_class.call(scope_feature:, role_name: "admin") }.to have_enqueued_job(RunDispatchJob)

    expect(result).to be_success
    expect(result.value).to have_attributes(status: "queued", role_name: "admin", project:)
  end

  it "rejects a scope feature that is not approved" do
    scope_feature.update!(approved: false)

    expect(described_class.call(scope_feature:, role_name: "admin").error.code).to eq(:scope_feature_not_approved)
    expect(Run.count).to eq(0)
  end

  it "rejects a role with no credential" do
    expect(described_class.call(scope_feature:, role_name: "billing").error.code).to eq(:credential_missing)
    expect(Run.count).to eq(0)
  end
end

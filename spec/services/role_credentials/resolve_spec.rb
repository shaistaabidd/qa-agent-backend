require "rails_helper"

RSpec.describe RoleCredentials::Resolve do
  let(:run) { create(:run, :running, role_name: "admin") }
  let(:token) { RoleCredentials::IssueFetchToken.call(run:).value }

  before { create(:role_credential, project: run.project, role_name: "admin", encrypted_credential_ref: "s3cr3t") }

  it "returns the credential value for an active run" do
    expect(described_class.call(token:).value).to eq("s3cr3t")
  end

  it "refuses a run that is no longer running" do
    run.update!(status: :completed)

    expect(described_class.call(token:).error.code).to eq(:run_not_active)
  end

  it "refuses a tampered, empty or expired token" do
    expect(described_class.call(token: "#{token}x").error.code).to eq(:invalid_token)
    expect(described_class.call(token: "").error.code).to eq(:invalid_token)

    travel_to(2.hours.from_now) { expect(described_class.call(token:).error.code).to eq(:invalid_token) }
  end
end

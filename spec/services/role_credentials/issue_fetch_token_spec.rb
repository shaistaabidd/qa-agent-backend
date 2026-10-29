require "rails_helper"

RSpec.describe RoleCredentials::IssueFetchToken do
  let(:run) { create(:run, role_name: "admin") }

  context "when the run's role has a credential" do
    let!(:credential) { create(:role_credential, project: run.project, role_name: "admin") }

    it "issues a signed token naming the run and credential" do
      result = described_class.call(run:)

      expect(result).to be_success
      payload = described_class.verifier.verified(result.value, purpose: described_class::PURPOSE)
      expect(payload).to eq("run_id" => run.id, "role_credential_id" => credential.id)
    end

    it "expires after an hour" do
      token = described_class.call(run:).value

      travel_to(described_class::TTL.from_now + 1.minute) do
        expect(described_class.verifier.verified(token, purpose: described_class::PURPOSE)).to be_nil
      end
    end

    it "is not valid for another purpose" do
      token = described_class.call(run:).value

      expect(described_class.verifier.verified(token, purpose: :github_install)).to be_nil
    end
  end

  it "fails when the role has no credential" do
    result = described_class.call(run:)

    expect(result.error.code).to eq(:credential_missing)
  end
end

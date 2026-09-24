require 'rails_helper'

RSpec.describe RoleCredentials::IssueFetchToken do
  let(:project) { create(:project) }
  let(:scope_feature) { create(:scope_feature, project: project) }
  let(:run) { create(:run, project: project, scope_feature: scope_feature, role_name: 'admin') }

  context "when a credential is configured for the run's role" do
    before { create(:role_credential, project: project, role_name: 'admin', encrypted_credential_ref: 's3cr3t') }

    it 'issues a token that decodes back to the run and credential ids' do
      result = described_class.call(run: run)

      expect(result).to be_success
      decoded = JWT.decode(result.token, Rails.application.secret_key_base, true, algorithm: 'HS256').first
      expect(decoded['run_id']).to eq(run.id)
      expect(decoded['role_credential_id']).to eq(RoleCredential.find_by(project: project, role_name: 'admin').id)
    end

    it 'sets a near-term expiry' do
      result = described_class.call(run: run)
      decoded = JWT.decode(result.token, Rails.application.secret_key_base, true, algorithm: 'HS256').first

      expect(decoded['exp']).to be_within(5).of(1.hour.from_now.to_i)
    end
  end

  context "when no credential is configured for the run's role" do
    it 'fails without raising' do
      result = described_class.call(run: run)

      expect(result).to be_failure
      expect(result.error).to match(/no credential configured/i)
    end
  end
end

require 'rails_helper'

RSpec.describe RoleCredentials::CreateOrUpdate do
  let(:project) { create(:project) }

  it 'creates a new credential for a role that has none yet' do
    result = described_class.call(project: project, role_name: 'admin', credential_value: 's3cr3t')

    expect(result).to be_success
    credential = project.role_credentials.find_by(role_name: 'admin')
    expect(credential.encrypted_credential_ref).to eq('s3cr3t')
  end

  it 'updates the existing credential instead of creating a duplicate' do
    described_class.call(project: project, role_name: 'admin', credential_value: 'old-pass')

    expect do
      described_class.call(project: project, role_name: 'admin', credential_value: 'new-pass')
    end.not_to change(RoleCredential, :count)

    expect(project.role_credentials.find_by(role_name: 'admin').encrypted_credential_ref).to eq('new-pass')
  end

  it 'fails cleanly when the credential value is blank' do
    result = described_class.call(project: project, role_name: 'admin', credential_value: '')

    expect(result).to be_failure
  end
end

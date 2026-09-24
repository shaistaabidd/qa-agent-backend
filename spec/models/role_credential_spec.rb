require 'rails_helper'

RSpec.describe RoleCredential, type: :model do
  it { is_expected.to belong_to(:project) }
  it { is_expected.to validate_presence_of(:role_name) }

  it 'only allows one credential per role per project' do
    create(:role_credential, role_name: 'admin')
    project = described_class.last.project
    duplicate = build(:role_credential, project: project, role_name: 'admin')

    expect(duplicate).not_to be_valid
  end

  it 'encrypts the credential value at rest' do
    credential = create(:role_credential, encrypted_credential_ref: 's3cr3t-value')

    raw_column_value = ActiveRecord::Base.connection.select_value(
      "SELECT encrypted_credential_ref FROM role_credentials WHERE id = #{credential.id}"
    )

    expect(raw_column_value).not_to eq('s3cr3t-value')
    expect(credential.reload.encrypted_credential_ref).to eq('s3cr3t-value')
  end
end

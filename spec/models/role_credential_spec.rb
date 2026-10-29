require "rails_helper"

RSpec.describe RoleCredential do
  it { is_expected.to belong_to(:project) }
  it { is_expected.to validate_presence_of(:role_name) }

  it "allows one credential per role per project" do
    existing = create(:role_credential, role_name: "admin")

    expect(build(:role_credential, project: existing.project, role_name: "admin")).not_to be_valid
  end

  it "encrypts the credential value at rest" do
    credential = create(:role_credential, encrypted_credential_ref: "s3cr3t-value")

    raw = described_class.connection.select_value(
      "SELECT encrypted_credential_ref FROM role_credentials WHERE id = #{credential.id}"
    )

    expect(raw).not_to include("s3cr3t-value")
    expect(credential.reload.encrypted_credential_ref).to eq("s3cr3t-value")
  end
end

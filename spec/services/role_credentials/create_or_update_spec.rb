require "rails_helper"

RSpec.describe RoleCredentials::CreateOrUpdate do
  let(:project) { create(:project) }

  it "creates a credential for a role that has none" do
    result = described_class.call(project:, role_name: "admin", credential_value: "s3cr3t")

    expect(result).to be_success
    expect(project.role_credentials.find_by(role_name: "admin").encrypted_credential_ref).to eq("s3cr3t")
  end

  it "replaces the existing credential instead of adding a second" do
    described_class.call(project:, role_name: "admin", credential_value: "old-pass")

    expect { described_class.call(project:, role_name: "admin", credential_value: "new-pass") }
      .not_to change(RoleCredential, :count)
    expect(project.role_credentials.find_by(role_name: "admin").encrypted_credential_ref).to eq("new-pass")
  end

  it "fails for a blank credential" do
    result = described_class.call(project:, role_name: "admin", credential_value: "")

    expect(result.error.code).to eq(:validation_failed)
  end
end

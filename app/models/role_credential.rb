class RoleCredential < ApplicationRecord
  ROLE_NAME_MAX_LENGTH = 100

  belongs_to :project

  # Stored with Active Record encryption at rest.
  encrypts :encrypted_credential_ref, deterministic: false

  validates :role_name, presence: true, length: { maximum: ROLE_NAME_MAX_LENGTH },
                        uniqueness: { scope: :project_id }
  validates :encrypted_credential_ref, presence: true
end

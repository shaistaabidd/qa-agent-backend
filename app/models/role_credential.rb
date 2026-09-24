class RoleCredential < ApplicationRecord
  belongs_to :project

  # v1: stores the actual credential using Rails' built-in encryption at rest
  # (staging-only scope, no Vault yet). The column name stays generic so a
  # later swap to a Vault/Secrets Manager pointer needs no schema change.
  encrypts :encrypted_credential_ref, deterministic: false

  validates :role_name, presence: true, uniqueness: { scope: :project_id }
  validates :encrypted_credential_ref, presence: true
end

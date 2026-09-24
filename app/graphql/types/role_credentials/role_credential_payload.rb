module Types
  module RoleCredentials
    class RoleCredentialPayload < Types::BaseObject
      field :role_credential, Types::RoleCredentials::RoleCredentialType, null: false
    end
  end
end

module Types
  module RoleCredentials
    # The encrypted credential value is intentionally never exposed here —
    # only which roles have a credential configured, and when.
    class RoleCredentialType < Types::BaseObject
      field :id, ID, null: false
      field :role_name, String, null: false
      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
    end
  end
end

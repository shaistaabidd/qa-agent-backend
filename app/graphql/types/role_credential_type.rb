module Types
  # The stored value is never exposed here, only which roles have a credential and when it was set.
  class RoleCredentialType < BaseObject
    description "A role the worker can sign in as; the credential itself is write-only"

    field :id, ID, null: false, description: "Unique identifier"
    field :role_name, String, null: false, description: "The role name"
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: "When it was first stored"
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false, description: "When it was last changed"
  end
end

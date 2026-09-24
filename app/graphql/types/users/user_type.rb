module Types
  module Users
    class UserType < Types::BaseObject
      field :id, ID, null: false
      field :email, String, null: false
      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    end
  end
end

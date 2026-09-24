module Types
  module Users
    class AuthPayload < Types::BaseObject
      field :token, String, null: false
      field :user, Types::Users::UserType, null: false
    end
  end
end

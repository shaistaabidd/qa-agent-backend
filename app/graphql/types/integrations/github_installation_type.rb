module Types
  module Integrations
    class GithubInstallationType < Types::BaseObject
      field :id, ID, null: false
      field :account_login, String, null: false
      field :account_type, String, null: false
    end
  end
end

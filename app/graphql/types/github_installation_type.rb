module Types
  class GithubInstallationType < BaseObject
    description "A GitHub App installation the user can access"

    field :id, ID, null: false, description: "GitHub's installation id"
    field :account_login, String, null: false, description: "The user or organization it is installed on"
    field :account_type, String, null: false, description: "User or Organization"
  end
end

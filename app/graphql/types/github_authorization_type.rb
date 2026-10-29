module Types
  class GithubAuthorizationType < BaseObject
    description "The installations GitHub confirmed the user can access"

    field :choice_token, String, null: false, description: "Pass back to selectGithubInstallation with the chosen id"
    field :installations, [GithubInstallationType], null: false, description: "Installations to choose from"
  end
end

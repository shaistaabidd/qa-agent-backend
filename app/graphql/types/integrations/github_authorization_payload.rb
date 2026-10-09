module Types
  module Integrations
    class GithubAuthorizationPayload < Types::BaseObject
      field :choice_token, String, null: false
      field :installations, [Types::Integrations::GithubInstallationType], null: false
    end
  end
end

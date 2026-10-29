module Queries
  module Runs
    # Called by the worker at the moment it needs to sign in, to exchange the short-lived token from
    # dispatch for the credential. The raw credential never travels in the dispatch payload or a job.
    class ResolveRoleCredential < BaseQuery
      agent_only!

      description "Agent worker only: the credential behind a run's fetch token"

      type String, null: false

      argument :token, String, description: "The credential_fetch_token from the dispatch payload"

      def resolve(token:) = value_or_raise!(::RoleCredentials::Resolve.call(token:))
    end
  end
end

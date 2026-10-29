module RoleCredentials
  # Exchanges the worker's fetch token for the credential value, only while the run is active.
  class Resolve < ApplicationService
    def initialize(token:)
      @token = token
    end

    def call
      payload = IssueFetchToken.verifier.verified(@token.to_s, purpose: IssueFetchToken::PURPOSE)
      return failure(:invalid_token) unless payload

      run = Run.find(payload["run_id"])
      return failure(:run_not_active) unless run.running?

      success(run.project.role_credentials.find(payload["role_credential_id"]).encrypted_credential_ref)
    end
  end
end

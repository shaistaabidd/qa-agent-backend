module RoleCredentials
  # Exchanges the worker's fetch token for the credential value, once, and only while the run is active.
  class Resolve < ApplicationService
    def initialize(token:)
      @token = token
    end

    def call
      payload = IssueFetchToken.verifier.verified(@token.to_s, purpose: IssueFetchToken::PURPOSE)
      return failure(:invalid_token) unless payload

      run = Run.find(payload["run_id"])
      return failure(:run_not_active) unless run.running?
      return failure(:invalid_token) unless claimed?(run)

      success(run.project.role_credentials.find(payload["role_credential_id"]).encrypted_credential_ref)
    end

    private

    # Atomic, so two concurrent exchanges can't both win: only the one that flips the column gets the value.
    def claimed?(run)
      # rubocop:disable-next Rails/SkipsModelValidations -- a conditional single-row claim; validations don't apply
      Run.where(id: run.id, credential_fetched_at: nil).update_all(credential_fetched_at: Time.current).positive?
    end
  end
end

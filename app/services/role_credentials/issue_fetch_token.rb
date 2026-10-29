module RoleCredentials
  # The token handed to the worker at dispatch. The raw credential never travels in the dispatch
  # payload or any job argument: the worker exchanges this token for it (Resolve) when it logs in.
  class IssueFetchToken < ApplicationService
    PURPOSE = :credential_fetch
    TTL = 1.hour

    def self.verifier = Rails.application.message_verifier(PURPOSE)

    def initialize(run:)
      @run = run
    end

    def call
      credential = @run.project.role_credentials.find_by(role_name: @run.role_name)
      return failure(:credential_missing) unless credential

      payload = { "run_id" => @run.id, "role_credential_id" => credential.id }
      success(self.class.verifier.generate(payload, purpose: PURPOSE, expires_in: TTL))
    end
  end
end

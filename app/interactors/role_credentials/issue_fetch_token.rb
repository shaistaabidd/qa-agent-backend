module RoleCredentials
  class IssueFetchToken < BaseInteractor
    # NOTE: do not `delegate :run, to: :context` — the interactor gem itself
    # defines #run/#run! as its invocation entry points; overriding them
    # makes #call silently never execute while the context still reports
    # success. See Runs::ReceiveResult for the same pitfall.

    def call
      return context.fail!(error: "No credential configured for role '#{context.run.role_name}'") unless role_credential

      context.token = JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
    end

    private

    def role_credential
      return @role_credential if defined?(@role_credential)

      @role_credential = context.run.project.role_credentials.find_by(role_name: context.run.role_name)
    end

    def payload
      {
        typ: 'credential_fetch',
        run_id: context.run.id,
        role_credential_id: role_credential.id,
        exp: 1.hour.from_now.to_i
      }
    end
  end
end

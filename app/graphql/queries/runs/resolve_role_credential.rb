module Queries
  module Runs
    # Called by the external agent worker, at the moment it needs to log in,
    # to exchange the short-lived token it was handed at dispatch time for the
    # actual credential value. The raw credential never travels through the
    # dispatch payload or any job args.
    class ResolveRoleCredential < Queries::BaseQuery
      include AuthenticableAgent

      argument :token, String, required: true

      type String, null: false

      def resolve(**params)
        authenticate_agent!
        decoded = decode(params[:token])
        run = Run.find(decoded['run_id'])
        raise not_active_error unless run.running?

        RoleCredential.find(decoded['role_credential_id']).encrypted_credential_ref
      rescue GraphQL::ExecutionError
        raise
      rescue JWT::DecodeError, JWT::ExpiredSignature
        execution_error(message: 'Invalid or expired token', code: 401)
      rescue ActiveRecord::RecordNotFound
        execution_error(message: 'Not found', code: 404)
      rescue StandardError => e
        execution_error(message: e.message)
      end

      private

      def decode(token)
        JWT.decode(token, Rails.application.secret_key_base, true, algorithm: 'HS256').first
      end

      def not_active_error
        execution_error(message: 'Run is not active', code: 422)
      end
    end
  end
end

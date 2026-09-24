module Mutations
  module Runs
    class ReceiveResult < BaseMutation
      include AuthenticableAgent

      argument :run_id, ID, required: true
      argument :status, Types::Enums::RunResultStatusEnum, required: true
      argument :audit_log_entries, [Types::Runs::AuditLogEntryAttributes], required: false, default_value: []

      type Types::Runs::RunPayload

      def resolve(**params)
        authenticate_agent!
        run = Run.find(params[:run_id])

        result = ::Runs::ReceiveResult.call(
          run: run,
          status: params[:status],
          audit_log_entries: params[:audit_log_entries]
        )

        result.success? ? result : execution_error(message: result.error)
      rescue GraphQL::ExecutionError
        raise
      rescue ActiveRecord::RecordNotFound
        execution_error(message: 'Run not found', code: 404)
      rescue StandardError => e
        execution_error(message: e.message)
      end
    end
  end
end

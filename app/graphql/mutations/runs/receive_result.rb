module Mutations
  module Runs
    class ReceiveResult < BaseMutation
      agent_only!

      description "Agent worker only: reports a run's audit trail, logs and final status"

      argument :run_id, ID, description: "The run being reported"
      argument :status, Types::RunResultStatusEnum, description: "The run's final (or blocking) status"
      argument :audit_log_entries, [Types::AuditLogEntryAttributes], required: false, default_value: [],
                                                                     description: "What the worker did"
      argument :network_log, GraphQL::Types::JSON, required: false, description: "Requests the worker observed"
      argument :summary, GraphQL::Types::JSON, required: false, description: "The worker's summary of the run"

      field :run, Types::RunType, null: false, description: "The run with its recorded result"

      def resolve(run_id:, status:, audit_log_entries:, network_log: nil, summary: nil)
        result = ::Runs::ReceiveResult.call(run: Run.find(run_id), status:, network_log:, summary:,
                                            audit_log_entries: audit_log_entries.map(&:to_h))

        { run: value_or_raise!(result) }
      end
    end
  end
end

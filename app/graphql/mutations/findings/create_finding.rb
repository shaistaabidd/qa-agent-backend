module Mutations
  module Findings
    # Called by the external agent worker as it discovers issues during a
    # run — potentially several times per run, before the final
    # receiveRunResult call closes the run out.
    class CreateFinding < BaseMutation
      include AuthenticableAgent

      argument :run_id, ID, required: true
      argument :title, String, required: true
      argument :repro_steps, [String], required: true
      argument :severity, Types::Enums::FindingSeverityEnum, required: true
      argument :screenshot, ApolloUploadServer::Upload, required: false

      type Types::Findings::FindingPayload

      def resolve(**params)
        authenticate_agent!
        run = Run.find(params[:run_id])

        result = ::Findings::Create.call(
          run: run,
          title: params[:title],
          repro_steps: params[:repro_steps],
          severity: params[:severity],
          screenshot: params[:screenshot]
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

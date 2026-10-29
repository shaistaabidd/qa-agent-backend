module Mutations
  module Findings
    # Called by the worker as it finds issues during a run: possibly several times per run, before the
    # final receiveRunResult closes the run.
    class CreateFinding < BaseMutation
      agent_only!

      description "Agent worker only: records an issue found during a run"

      argument :run_id, ID, description: "The run that found it"
      argument :title, String, description: "Short summary; unique within the run"
      argument :repro_steps, [String], description: "How to reproduce it"
      argument :severity, Types::FindingSeverityEnum, description: "How serious it is"
      argument :screenshot, Types::UploadType, required: false, description: "A screenshot, as a multipart upload"
      argument :category, String, required: false, description: "The worker's category for it"
      argument :details, GraphQL::Types::JSON, required: false, description: "Evidence the worker recorded"
      argument :fingerprint, String, required: false, description: "Findings sharing one are the same issue"

      field :finding, Types::FindingType, null: false, description: "The recorded finding"

      def resolve(run_id:, **attributes)
        { finding: value_or_raise!(::Findings::Create.call(run: Run.find(run_id), **attributes)) }
      end
    end
  end
end

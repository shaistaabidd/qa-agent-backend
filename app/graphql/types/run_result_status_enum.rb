module Types
  # The statuses the worker may report through receiveRunResult: a subset of RunStatusEnum, because
  # queued and running are only ever set by this API.
  class RunResultStatusEnum < BaseEnum
    description "The final (or blocking) status the worker reports for a run"

    value "COMPLETED", "The worker finished", value: "completed"
    value "FAILED", "The run failed", value: "failed"
    value "BLOCKED", "The worker could not continue", value: "blocked"
  end
end

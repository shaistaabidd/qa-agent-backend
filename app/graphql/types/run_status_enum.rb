module Types
  class RunStatusEnum < BaseEnum
    description "Where a run is in its lifecycle"

    value "QUEUED", "Waiting to be handed to the worker", value: "queued"
    value "RUNNING", "The worker is exploring the app", value: "running"
    value "BLOCKED", "The worker could not continue, for example it could not sign in", value: "blocked"
    value "COMPLETED", "The worker finished", value: "completed"
    value "FAILED", "The run failed or was lost", value: "failed"
  end
end

module Types
  module Enums
    # The terminal (or blocking) states the external agent worker can report
    # back via receiveRunResult — a subset of RunStatusEnum (no queued/running,
    # since those are only ever set by this backend, not reported by a worker).
    class RunResultStatusEnum < Types::BaseEnum
      value 'COMPLETED', value: 'completed'
      value 'FAILED', value: 'failed'
      value 'BLOCKED', value: 'blocked'
    end
  end
end

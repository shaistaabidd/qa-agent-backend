module Types
  module Enums
    class RunStatusEnum < Types::BaseEnum
      value 'QUEUED', value: 'queued'
      value 'RUNNING', value: 'running'
      value 'BLOCKED', value: 'blocked'
      value 'COMPLETED', value: 'completed'
      value 'FAILED', value: 'failed'
    end
  end
end

module Types
  module Runs
    class RunPayload < Types::BaseObject
      field :run, Types::Runs::RunType, null: false
    end
  end
end

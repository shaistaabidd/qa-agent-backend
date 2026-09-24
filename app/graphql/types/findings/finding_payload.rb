module Types
  module Findings
    class FindingPayload < Types::BaseObject
      field :finding, Types::Findings::FindingType, null: false
    end
  end
end

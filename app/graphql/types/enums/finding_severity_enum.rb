module Types
  module Enums
    class FindingSeverityEnum < Types::BaseEnum
      value 'LOW', value: 'low'
      value 'MEDIUM', value: 'medium'
      value 'HIGH', value: 'high'
      value 'CRITICAL', value: 'critical'
    end
  end
end

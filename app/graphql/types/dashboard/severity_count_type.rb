module Types
  module Dashboard
    class SeverityCountType < Types::BaseObject
      field :severity, Types::Enums::FindingSeverityEnum, null: false
      field :count, Integer, null: false
    end
  end
end

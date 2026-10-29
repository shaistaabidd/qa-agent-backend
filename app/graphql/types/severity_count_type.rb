module Types
  class SeverityCountType < BaseObject
    description "Open issues of one severity"

    field :severity, FindingSeverityEnum, null: false, description: "The severity"
    field :count, Integer, null: false, description: "Open issues with it"
  end
end

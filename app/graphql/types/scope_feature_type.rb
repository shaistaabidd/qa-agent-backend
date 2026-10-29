module Types
  class ScopeFeatureType < BaseObject
    description "A part of the app found in its repository that can be tested once approved"

    field :id, ID, null: false, description: "Unique identifier"
    field :name, String, null: false, description: "Feature name"
    field :route, String, description: "The route it was found at"
    field :source, String, description: "Where in the repository it was found"
    field :approved, Boolean, null: false, description: "Whether runs may target it"
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: "When it was found"
  end
end

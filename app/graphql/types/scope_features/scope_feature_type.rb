module Types
  module ScopeFeatures
    class ScopeFeatureType < Types::BaseObject
      field :id, ID, null: false
      field :name, String, null: false
      field :route, String, null: true
      field :source, String, null: true
      field :approved, Boolean, null: false
      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    end
  end
end

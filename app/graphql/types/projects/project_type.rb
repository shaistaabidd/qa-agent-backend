module Types
  module Projects
    class ProjectType < Types::BaseObject
      field :id, ID, null: false
      field :name, String, null: false
      field :target_url, String, null: false
      field :repo_connected, Boolean, null: false, resolver_method: :repo_connected?
      field :created_at, GraphQL::Types::ISO8601DateTime, null: false

      def repo_connected?
        object.repo_connection_id.present?
      end
    end
  end
end

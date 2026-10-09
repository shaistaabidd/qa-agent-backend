module Types
  module Projects
    class ProjectType < Types::BaseObject
      field :id, ID, null: false
      field :name, String, null: false
      field :target_url, String, null: false
      field :repo_connected, Boolean, null: false, resolver_method: :repo_connected?
      field :github_installed, Boolean, null: false, resolver_method: :github_installed?
      field :repo_full_name, String, null: true
      field :created_at, GraphQL::Types::ISO8601DateTime, null: false

      def repo_connected?
        object.repo_connection_id.present?
      end

      def github_installed?
        object.integrations.github.exists?
      end

      def repo_full_name
        object.repo_connection&.repo_full_name
      end
    end
  end
end

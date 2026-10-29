module Types
  class ProjectType < BaseObject
    description "An app under test"

    field :id, ID, null: false, description: "Unique identifier"
    field :name, String, null: false, description: "Display name"
    field :target_url, String, null: false, description: "The deployed app the worker explores"
    field :repo_connected, Boolean, null: false, method: :repo_connected?,
                                    description: "Whether a GitHub repository is linked for scanning"
    field :github_installed, Boolean, null: false, method: :github_installed?,
                                      description: "Whether the GitHub App is installed for this project"
    field :repo_full_name, String, description: "The linked repository, as owner/name"
    field :my_role, ProjectRoleEnum,
          description: "The signed-in user's role here; null for a super admin who is not a member"
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: "When the project was created"

    def repo_full_name = object.repo_connection&.repo_full_name

    def my_role = context.dataloader.with(Sources::ProjectRole, context[:current_user].id).load(object.id)
  end
end

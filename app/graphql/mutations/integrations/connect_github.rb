module Mutations
  module Integrations
    class ConnectGithub < BaseMutation
      include ProjectAccess

      description "Project admins: links one of the installation's repositories to the project"

      argument :project_id, ID, description: "Project to connect"
      argument :repo_full_name, String, description: "Repository as owner/name"

      field :project, Types::ProjectType, null: false, description: "The project"

      def resolve(project_id:, repo_full_name:)
        project = find_project(project_id, to: :manage?)

        { project: value_or_raise!(::Integrations::ConnectGithub.call(project:, repo_full_name:)) }
      end
    end
  end
end

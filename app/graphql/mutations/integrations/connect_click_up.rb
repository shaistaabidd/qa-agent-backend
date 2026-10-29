module Mutations
  module Integrations
    class ConnectClickUp < BaseMutation
      include ProjectAccess

      description "Project admins: sets the ClickUp list findings are posted into"

      argument :project_id, ID, description: "Project to connect"
      argument :list_id, String, description: "ClickUp list id"

      field :project, Types::ProjectType, null: false, description: "The project"

      def resolve(project_id:, list_id:)
        project = find_project(project_id, to: :manage?)

        { project: value_or_raise!(::Integrations::ConnectClickUp.call(project:, list_id:)) }
      end
    end
  end
end

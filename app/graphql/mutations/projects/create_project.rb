module Mutations
  module Projects
    class CreateProject < BaseMutation
      description "Creates a project; the creator becomes its admin"

      rate_limit to: 30, within: 1.hour, by: ->(_) { current_user.id }

      argument :name, String, description: "Display name"
      argument :target_url, String, description: "The deployed app the worker will explore"

      field :project, Types::ProjectType, null: false, description: "The new project"

      def resolve(name:, target_url:)
        authorize! Project, to: :create?

        { project: value_or_raise!(::Projects::Create.call(user: current_user, name:, target_url:)) }
      end
    end
  end
end

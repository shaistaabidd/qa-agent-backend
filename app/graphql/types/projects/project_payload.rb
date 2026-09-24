module Types
  module Projects
    class ProjectPayload < Types::BaseObject
      field :project, Types::Projects::ProjectType, null: false
    end
  end
end

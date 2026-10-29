module Queries
  module Projects
    class FetchProject < BaseQuery
      include ProjectAccess

      description "One project the signed-in user can see"

      type Types::ProjectType, null: false

      argument :id, ID, description: "Project to fetch"

      def resolve(id:) = find_project(id)
    end
  end
end

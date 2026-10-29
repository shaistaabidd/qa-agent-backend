module Queries
  module Projects
    class FetchCoverage < BaseQuery
      include ProjectAccess

      description "How much of a project's approved scope has been run"

      type Types::CoverageType, null: false

      argument :project_id, ID, description: "Project to measure"

      def resolve(project_id:) = ::Projects::Coverage.new(find_project(project_id)).call
    end
  end
end

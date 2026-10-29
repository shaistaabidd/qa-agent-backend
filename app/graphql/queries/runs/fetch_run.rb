module Queries
  module Runs
    class FetchRun < BaseQuery
      include ProjectAccess

      description "One run, with what the worker did"

      type Types::RunType, null: false

      argument :id, ID, description: "Run to fetch"

      def resolve(id:)
        run = find_in_projects(Run, id)
        authorize! run.project, to: :show?
        run
      end
    end
  end
end

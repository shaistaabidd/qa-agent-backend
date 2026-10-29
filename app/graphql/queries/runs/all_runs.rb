module Queries
  module Runs
    class AllRuns < BaseQuery
      include Paginatable
      include ProjectAccess

      description "A project's runs, newest first"

      type Types::RunPaginationType, null: false

      argument :project_id, ID, description: "Project whose runs to list"
      argument :filter, Types::RunFilterInput, required: false, description: "Status filter and paging"

      def resolve(project_id:, filter: nil)
        project = find_project(project_id)
        options = filter.to_h

        runs = project.runs.includes(:scope_feature, :audit_log_entries).order(created_at: :desc, id: :desc)
        runs = runs.where(status: options[:status]) if options[:status]
        paginate_with_filter(runs, options.except(:status))
      end
    end
  end
end

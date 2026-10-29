module Queries
  module Runs
    class AllRuns < BaseQuery
      include Paginatable
      include ProjectAccess

      description "A project's runs, newest first"

      type Types::RunPaginationType, null: false

      argument :project_id, ID, description: "Project whose runs to list"
      argument :filter, Types::RunFilterInput, required: false, description: "Status filter and paging"

      extras [:lookahead]

      # Associations are only loaded when the query asks for them.
      def resolve(lookahead:, project_id:, filter: nil)
        project = find_project(project_id)
        options = filter.to_h

        fields = lookahead.selection(:all_data)
        runs = project.runs.order(created_at: :desc, id: :desc)
        runs = runs.includes(:scope_feature) if fields.selects?(:scope_feature)
        runs = runs.includes(:audit_log_entries) if fields.selects?(:audit_log_entries)
        runs = runs.where(status: options[:status]) if options[:status]
        paginate_with_filter(runs, options.except(:status))
      end
    end
  end
end

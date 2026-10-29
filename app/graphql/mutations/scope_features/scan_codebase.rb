module Mutations
  module ScopeFeatures
    class ScanCodebase < BaseMutation
      include ProjectAccess

      description "Project admins: reads the connected repository in the background and records its scope features"

      rate_limit to: 10, within: 10.minutes, by: ->(_) { current_user.id }

      argument :project_id, ID, description: "Project to scan"

      field :success, Boolean, null: false, description: "Whether the scan was queued"
      field :message, String, description: "What happened"

      def resolve(project_id:)
        project = find_project(project_id, to: :manage?)
        unless project.repo_connection
          raise GraphqlErrors.build(I18n.t("errors.repo_not_connected"),
                                    :repo_not_connected)
        end

        RepoScanJob.perform_later(project.id)
        { success: true, message: "Scan enqueued" }
      end
    end
  end
end

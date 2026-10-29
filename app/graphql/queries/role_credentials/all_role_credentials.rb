module Queries
  module RoleCredentials
    class AllRoleCredentials < BaseQuery
      include ProjectAccess

      description "The roles a project has credentials for. The credential values are never returned."

      type [Types::RoleCredentialType], null: false

      argument :project_id, ID, description: "Project whose roles to list"

      def resolve(project_id:) = find_project(project_id).role_credentials.order(:role_name)
    end
  end
end

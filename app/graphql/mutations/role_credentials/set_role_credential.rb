module Mutations
  module RoleCredentials
    class SetRoleCredential < BaseMutation
      include ProjectAccess

      description "Project admins: stores (or replaces) the credential the worker signs in with for a role"

      rate_limit to: 30, within: 10.minutes, by: ->(_) { current_user.id }

      argument :project_id, ID, description: "Project the role belongs to"
      argument :role_name, String, description: "Role name, for example admin"
      argument :credential_value, String,
               description: "JSON like {\"email\":\"...\",\"password\":\"...\"} or \"email:password\"; write-only"

      field :role_credential, Types::RoleCredentialType, null: false, description: "The stored role (no value)"

      def resolve(project_id:, role_name:, credential_value:)
        project = find_project(project_id, to: :manage?)

        { role_credential: value_or_raise!(::RoleCredentials::CreateOrUpdate.call(project:, role_name:,
                                                                                  credential_value:)) }
      end
    end
  end
end

# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    field :register_user, mutation: Mutations::Users::RegisterUser
    field :login_user, mutation: Mutations::Users::LoginUser
    field :create_project, mutation: Mutations::Projects::CreateProject
    field :connect_github, mutation: Mutations::Integrations::ConnectGithub
    field :scan_codebase, mutation: Mutations::ScopeFeatures::ScanCodebase
    field :approve_scope_feature, mutation: Mutations::ScopeFeatures::ApproveScopeFeature
    field :dispatch_run, mutation: Mutations::Runs::DispatchRun
    field :receive_run_result, mutation: Mutations::Runs::ReceiveResult
    field :connect_click_up, mutation: Mutations::Integrations::ConnectClickUp
    field :create_finding, mutation: Mutations::Findings::CreateFinding
    field :set_role_credential, mutation: Mutations::RoleCredentials::SetRoleCredential
  end
end

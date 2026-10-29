module Types
  class MutationType < BaseObject
    description "Write operations"

    # Authentication
    field :register_user, mutation: Mutations::Auth::RegisterUser
    field :login_user, mutation: Mutations::Auth::LoginUser
    field :validate_otp, mutation: Mutations::Auth::ValidateOtp
    field :sign_in_with_google, mutation: Mutations::Auth::SignInWithGoogle
    field :resend_otp, mutation: Mutations::Auth::ResendOtp
    field :send_reset_password_instructions, mutation: Mutations::Auth::SendResetPasswordInstructions
    field :set_password, mutation: Mutations::Auth::SetPassword
    field :accept_invitation, mutation: Mutations::Auth::AcceptInvitation
    field :logout, mutation: Mutations::Auth::Logout
    field :impersonate_user, mutation: Mutations::Auth::ImpersonateUser
    field :request_email_change, mutation: Mutations::Auth::RequestEmailChange
    field :resend_email_change_code, mutation: Mutations::Auth::ResendEmailChangeCode
    field :confirm_email_change, mutation: Mutations::Auth::ConfirmEmailChange

    # Users
    field :update_user, mutation: Mutations::Users::UpdateUser
    field :update_password, mutation: Mutations::Users::UpdatePassword
    field :archive_user, mutation: Mutations::Users::ArchiveUser
    field :update_user_access, mutation: Mutations::Users::UpdateUserAccess

    # Projects and scope
    field :create_project, mutation: Mutations::Projects::CreateProject
    field :scan_codebase, mutation: Mutations::ScopeFeatures::ScanCodebase
    field :approve_scope_feature, mutation: Mutations::ScopeFeatures::ApproveScopeFeature
    field :set_role_credential, mutation: Mutations::RoleCredentials::SetRoleCredential

    # Runs
    field :dispatch_run, mutation: Mutations::Runs::DispatchRun

    # Integrations
    field :complete_github_installation, mutation: Mutations::Integrations::CompleteGithubInstallation
    field :authorize_github_user, mutation: Mutations::Integrations::AuthorizeGithubUser
    field :select_github_installation, mutation: Mutations::Integrations::SelectGithubInstallation
    field :connect_github, mutation: Mutations::Integrations::ConnectGithub
    field :connect_click_up, mutation: Mutations::Integrations::ConnectClickUp

    # Agent worker (X-Agent-Token): see docs/agent-contract.md
    field :receive_run_result, mutation: Mutations::Runs::ReceiveResult
    field :create_finding, mutation: Mutations::Findings::CreateFinding

    # Invitations
    field :create_invitation, mutation: Mutations::Invitations::CreateInvitation
    field :resend_invitation, mutation: Mutations::Invitations::ResendInvitation
    field :delete_invitation, mutation: Mutations::Invitations::DeleteInvitation
  end
end

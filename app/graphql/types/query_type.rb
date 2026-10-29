module Types
  class QueryType < BaseObject
    description "Read operations"

    field :all_email_logs, resolver: Queries::EmailLogs::AllEmailLogs
    field :all_sms_logs, resolver: Queries::SmsLogs::AllSmsLogs
    field :all_findings, resolver: Queries::Findings::AllFindings
    field :all_github_repositories, resolver: Queries::Integrations::AllGithubRepositories
    field :all_projects, resolver: Queries::Projects::AllProjects
    field :all_role_credentials, resolver: Queries::RoleCredentials::AllRoleCredentials
    field :all_runs, resolver: Queries::Runs::AllRuns
    field :all_scope_features, resolver: Queries::ScopeFeatures::AllScopeFeatures
    field :all_users, resolver: Queries::Users::AllUsers
    field :fetch_email_log, resolver: Queries::EmailLogs::FetchEmailLog
    field :fetch_coverage, resolver: Queries::Projects::FetchCoverage
    field :fetch_feature_flags, resolver: Queries::FeatureFlags::FetchFeatureFlags
    field :fetch_finding, resolver: Queries::Findings::FetchFinding
    field :fetch_findings_summary, resolver: Queries::Findings::FetchFindingsSummary
    field :fetch_github_authorize_url, resolver: Queries::Integrations::FetchGithubAuthorizeUrl
    field :fetch_github_install_url, resolver: Queries::Integrations::FetchGithubInstallUrl
    field :fetch_project, resolver: Queries::Projects::FetchProject
    field :fetch_public_feature_flags, resolver: Queries::FeatureFlags::FetchPublicFeatureFlags
    field :fetch_run, resolver: Queries::Runs::FetchRun
    field :fetch_sms_log, resolver: Queries::SmsLogs::FetchSmsLog
    field :fetch_user, resolver: Queries::Users::FetchUser
    field :resolve_role_credential, resolver: Queries::Runs::ResolveRoleCredential
    field :validate_invitation_token, resolver: Queries::Auth::ValidateInvitationToken
  end
end

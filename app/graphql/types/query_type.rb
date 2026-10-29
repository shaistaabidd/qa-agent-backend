module Types
  class QueryType < BaseObject
    description "Read operations"

    field :all_email_logs, resolver: Queries::EmailLogs::AllEmailLogs
    field :all_sms_logs, resolver: Queries::SmsLogs::AllSmsLogs
    field :all_users, resolver: Queries::Users::AllUsers
    field :fetch_email_log, resolver: Queries::EmailLogs::FetchEmailLog
    field :fetch_feature_flags, resolver: Queries::FeatureFlags::FetchFeatureFlags
    field :fetch_public_feature_flags, resolver: Queries::FeatureFlags::FetchPublicFeatureFlags
    field :fetch_sms_log, resolver: Queries::SmsLogs::FetchSmsLog
    field :fetch_user, resolver: Queries::Users::FetchUser
    field :validate_invitation_token, resolver: Queries::Auth::ValidateInvitationToken
  end
end

# An expected business failure. The code becomes the GraphQL error's
# extensions.code, so it is part of the API contract.
class ServiceError < Data.define(:code, :message)
  CODES = %i[
    access_revoked
    credential_missing
    github_access_denied
    github_failed
    github_link_expired
    github_not_installed
    github_repo_inaccessible
    github_wrong_user
    google_sign_in_disabled
    google_sign_in_failed
    invalid_code
    invalid_credentials
    invalid_run_transition
    invalid_token
    rate_limited
    repo_not_connected
    run_not_active
    scope_feature_not_approved
    sign_up_disabled
    validation_failed
  ].freeze

  def initialize(code:, message:)
    raise ArgumentError, "Unknown service error code: #{code}" unless CODES.include?(code)

    super
  end
end

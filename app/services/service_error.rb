# An expected business failure. The code becomes the GraphQL error's
# extensions.code, so it is part of the API contract.
class ServiceError < Data.define(:code, :message)
  CODES = %i[
    access_revoked
    google_sign_in_disabled
    google_sign_in_failed
    invalid_code
    invalid_credentials
    invalid_token
    rate_limited
    sign_up_disabled
    validation_failed
  ].freeze

  def initialize(code:, message:)
    raise ArgumentError, "Unknown service error code: #{code}" unless CODES.include?(code)

    super
  end
end

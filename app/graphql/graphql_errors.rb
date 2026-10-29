# Builds every client-facing error, so codes and messages stay consistent.
# extensions.code is what the frontend's error link switches on.
module GraphqlErrors
  module_function

  def unauthenticated = build(I18n.t("errors.unauthenticated"), :unauthenticated)
  def forbidden = build(I18n.t("errors.forbidden"), :forbidden)
  def not_found = build(I18n.t("errors.not_found"), :not_found)
  def rate_limited = build(I18n.t("errors.rate_limited"), :rate_limited)
  def internal = build(I18n.t("errors.internal"), :internal_server_error)

  def from_service_error(error) = build(error.message, error.code)

  def build(message, code)
    GraphQL::ExecutionError.new(message, extensions: { code: code.to_s.upcase })
  end
end

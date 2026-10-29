# One business operation per subclass, exposed as `.call(...)`. Expected
# failures come back as a ServiceResult; unexpected ones raise.
class ApplicationService
  def self.call(...) = new(...).call

  private

  def success(value = nil) = ServiceResult.success(value)

  # The one way to fail. Pass a record whose validation failed and its errors
  # become the message; otherwise the message is `errors.<code>` unless given.
  def failure(code, message = nil, record: nil)
    message ||= record ? record.errors.full_messages.to_sentence : I18n.t("errors.#{code}")
    ServiceResult.failure(ServiceError.new(code:, message:))
  end
end

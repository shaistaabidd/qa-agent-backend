# Mirrors the frontend's PASSWORD_RULES. The 72-byte ceiling is bcrypt's limit.
class PasswordStrengthValidator < ActiveModel::EachValidator
  MIN_LENGTH = 8
  MAX_BYTES = 72
  RULES = {
    /[A-Z]/ => :password_missing_uppercase,
    /[a-z]/ => :password_missing_lowercase,
    /[^A-Za-z0-9]/ => :password_missing_special
  }.freeze

  def validate_each(record, attribute, value)
    record.errors.add(attribute, :too_short, count: MIN_LENGTH) if value.length < MIN_LENGTH
    record.errors.add(attribute, :password_too_long, count: MAX_BYTES) if value.bytesize > MAX_BYTES

    RULES.each do |pattern, error|
      record.errors.add(attribute, error) unless value.match?(pattern)
    end
  end
end

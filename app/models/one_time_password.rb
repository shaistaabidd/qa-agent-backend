# A short numeric code emailed to the user. One live code per user and
# purpose; issuing a new one replaces the old. Only an HMAC of the code is stored.
class OneTimePassword < ApplicationRecord
  CODE_LENGTH = 6
  TTL = 10.minutes
  MAX_FAILED_ATTEMPTS = 5
  RESEND_COOLDOWN = 30.seconds
  SIGN_IN_PURPOSES = %w[login password_reset].freeze

  belongs_to :user

  # 2 belonged to the removed two-code email change; never reuse it.
  enum :purpose, { login: 0, password_reset: 1, email_confirmation: 3 }, validate: true

  # Atomically creates or replaces the user's code for this purpose and
  # returns the plain code for delivery.
  def self.issue!(user:, purpose:)
    code = SecureRandom.random_number(10**CODE_LENGTH).to_s.rjust(CODE_LENGTH, "0")

    upsert(
      { user_id: user.id, purpose: purposes.fetch(purpose.to_s), code_digest: digest(code),
        failed_attempts: 0, expires_at: TTL.from_now },
      unique_by: %i[user_id purpose]
    )

    code
  end

  # The code in flight for an email address and purpose. The purpose pins it to
  # the user's flow, so a login never touches the password-reset code (or the reverse).
  def self.pending_for(email, purpose:)
    includes(:user).joins(:user)
                   .find_by(purpose: purpose.to_s, users: { email: User.normalize_value_for(:email, email) })
  end

  def self.digest(code)
    OpenSSL::HMAC.hexdigest("SHA256", digest_key, code.to_s)
  end

  def self.digest_key
    @digest_key ||= Rails.application.key_generator.generate_key("one_time_password")
  end

  def issued_at = expires_at - TTL
  def expired? = expires_at.past?
  def locked? = failed_attempts >= MAX_FAILED_ATTEMPTS
  def resendable? = issued_at <= RESEND_COOLDOWN.ago

  # Counts a wrong guess, so a code dies after MAX_FAILED_ATTEMPTS.
  def correct_code?(code)
    return false if expired? || locked?
    return true if ActiveSupport::SecurityUtils.secure_compare(code_digest, self.class.digest(code))

    increment!(:failed_attempts)
    false
  end
end

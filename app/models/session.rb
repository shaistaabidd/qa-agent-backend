# A signed-in device. The client holds a random bearer token; only its SHA-256
# digest is stored, so a database leak does not leak usable tokens.
class Session < ApplicationRecord
  TOKEN_LENGTH = 48
  TTL = 7.days
  IMPERSONATION_TTL = 1.hour
  IDLE_TIMEOUT = 2.days
  ACTIVITY_RECORD_INTERVAL = 5.minutes
  USER_AGENT_MAX_LENGTH = 255

  belongs_to :user
  belongs_to :impersonator, class_name: "User", optional: true

  scope :active, -> { where(expires_at: Time.current.., last_active_at: IDLE_TIMEOUT.ago..) }
  scope :expired, -> { where(expires_at: ...Time.current).or(where(last_active_at: ...IDLE_TIMEOUT.ago)) }

  before_validation :assign_token, :assign_expiry, on: :create
  before_validation -> { self.last_active_at ||= Time.current }, on: :create

  # Plain token, readable only on the instance that created it.
  attr_reader :token

  def self.find_by_token(token)
    return if token.blank?

    active.includes(:user).find_by(token_digest: digest(token))
  end

  def self.start_for!(user, impersonator: nil)
    create!(user:, impersonator:, ip_address: Current.ip_address,
            user_agent: Current.user_agent&.truncate(USER_AGENT_MAX_LENGTH))
  end

  def self.digest(token)
    OpenSSL::Digest::SHA256.hexdigest(token)
  end

  def impersonated? = impersonator_id.present?

  # The user can still sign in and, for an impersonated session, so can the
  # super admin behind it: revoking or archiving the admin ends it too.
  def usable?
    return false unless user.can_sign_in?
    return true unless impersonated?

    impersonator.super_admin? && impersonator.can_sign_in?
  end

  # Written at most every ACTIVITY_RECORD_INTERVAL so requests don't each cost a write.
  def record_activity!
    touch(:last_active_at) if last_active_at <= ACTIVITY_RECORD_INTERVAL.ago
  end

  private

  def assign_token
    @token = SecureRandom.base58(TOKEN_LENGTH)
    self.token_digest = self.class.digest(@token)
  end

  def assign_expiry
    self.expires_at ||= (impersonated? ? IMPERSONATION_TTL : TTL).from_now
  end
end

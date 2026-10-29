# One row per outgoing SMS, for the super-admin SMS Logs screen. It records what
# Twilio answered when we sent it: pending until handed over, then Twilio's own
# status (queued, or accepted through a Messaging Service), or failed with
# Twilio's error. Later delivery statuses are not tracked: there are no callbacks.
class SmsLog < ApplicationRecord
  RETENTION = 90.days
  ERROR_MESSAGE_MAX_LENGTH = 1_000

  belongs_to :user, optional: true

  enum :message_type, { welcome: 0 }, validate: true
  enum :status, { pending: 0, queued: 1, failed: 2, accepted: 3 }, validate: true

  validates :recipient, :body, presence: true

  scope :expired, -> { where(created_at: ...RETENTION.ago) }

  def record_delivery!(delivery)
    update!(status: delivery.status, provider_sid: delivery.sid, sent_at: Time.current)
  end

  # Stores what the provider answered: its error code, and our plain-words text
  # for codes we know (config/locales `sms.errors`), otherwise the provider's own
  # message.
  def mark_failed!(error_code: nil, error_message: nil)
    known = I18n.t("sms.errors.#{error_code}", default: nil) if error_code.present?
    text = known || error_message.presence || I18n.t("sms.errors.unknown", code: error_code)
    update!(status: :failed, error_code: error_code.presence, error_message: text.truncate(ERROR_MESSAGE_MAX_LENGTH))
  end
end

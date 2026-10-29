# One row per outgoing email, for the super-admin Email Logs screen. Sidekiq
# retries update the same row, so status and attempts reflect the latest try.
# Bodies are stored as sent except for the secrets the mailer hid (sign-in
# codes, invitation tokens); they are still personal data, so only super
# admins may read them.
class EmailLog < ApplicationRecord
  RETENTION = 90.days
  RECIPIENT_SEPARATOR = ", ".freeze
  ERROR_MESSAGE_MAX_LENGTH = 1_000
  HIDDEN = "[hidden]".freeze

  enum :status, { success: 0, failed: 1 }, validate: true

  validates :recipient, :mailer, :mailer_method, presence: true

  scope :expired, -> { where(created_at: ...RETENTION.ago) }
  # Bodies are large HTML; list pages read them only when the client asks.
  scope :without_body, -> { select(column_names - %w[body]) }

  # Records one delivery attempt of the mailer's message on its email's row.
  def self.record_attempt(mailer, delivery_id:, error: nil)
    log = find_or_initialize_by(delivery_id:)
    log.attempts += 1 if log.persisted?
    log.update!(**email_attributes(mailer), **outcome_attributes(error))
  end

  def self.email_attributes(mailer)
    message = mailer.message
    { recipient: Array(message.to).join(RECIPIENT_SEPARATOR), mailer: mailer.class.name,
      mailer_method: mailer.action_name, subject: message.subject,
      body: stored_body(message, hidden: mailer.email_log_secrets) }
  end

  def self.outcome_attributes(error)
    return { status: :success, sent_at: Time.current, error_message: nil } unless error

    message = "#{error.class}: #{error.message}".truncate(ERROR_MESSAGE_MAX_LENGTH)
    { status: :failed, sent_at: nil, error_message: message }
  end

  def self.stored_body(message, hidden:)
    body = (message.html_part || message.text_part || message).body.decoded
    hidden.compact_blank.each { |secret| body = body.gsub(secret, HIDDEN) }
    body
  end
  private_class_method :email_attributes, :outcome_attributes, :stored_body
end

# Records each delivery attempt on the email's EmailLog row for the super-admin
# Email Logs screen. Secrets a mailer names with hide_in_email_log (sign-in
# codes, invitation tokens) reach the recipient but not the stored copy, so an
# admin reading the logs can't use them to get into someone else's account.
module EmailLogging
  extend ActiveSupport::Concern

  included do
    around_deliver :record_email_log
  end

  def email_log_secrets = @email_log_secrets.to_a

  private

  def hide_in_email_log(*secrets)
    @email_log_secrets = secrets
  end

  def record_email_log
    yield
    write_email_log
  rescue StandardError => e
    # Record the failure, then re-raise so Sidekiq retries the delivery.
    write_email_log(error: e)
    raise
  end

  # A failed log write must never fail (and so re-send) an email that went out.
  # Outside EmailDeliveryJob (deliver_now) every delivery is its own email.
  def write_email_log(error: nil)
    EmailLog.record_attempt(self, delivery_id: Current.email_delivery_id || SecureRandom.uuid, error:)
  rescue StandardError => e
    Rails.error.report(e, handled: true)
  end
end

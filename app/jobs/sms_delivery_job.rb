# Hands a pending SmsLog to Twilio and records its answer: Twilio's status once
# it takes the SMS, failed with its error if it refuses or every retry fails.
class SmsDeliveryJob < ApplicationJob
  ATTEMPTS = 5

  queue_as :default

  retry_on Sms::TransientError, wait: :polynomially_longer, attempts: ATTEMPTS do |job, error|
    SmsLog.find_by(id: job.arguments.first)&.mark_failed!(error_message: error.message)
  end

  def perform(sms_log_id)
    sms_log = SmsLog.find(sms_log_id)
    # A retry after a successful hand-off must not send the SMS twice.
    return unless sms_log.pending?

    delivery = Sms::TwilioSender.new.deliver(to: sms_log.recipient, body: sms_log.body)
    sms_log.record_delivery!(delivery)
  rescue Sms::PermanentError => e
    sms_log.mark_failed!(error_code: e.code, error_message: e.message)
  end
end

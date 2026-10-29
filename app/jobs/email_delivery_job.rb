# Rails' mail delivery job, plus the job id in Current so EmailLogging keeps one
# log row per email across Sidekiq retries (a retry reuses the job id).
class EmailDeliveryJob < ActionMailer::MailDeliveryJob
  # Mail jobs carry one-time codes and invitation tokens; keep them out of job logs.
  self.log_arguments = false

  # Inherits from Rails' mail job, not ApplicationJob: the recipient record was
  # deleted before delivery, so there is nothing to send and retrying can't help.
  discard_on ActiveJob::DeserializationError

  around_perform do |job, block|
    Current.set(email_delivery_id: job.job_id) { block.call }
  end
end

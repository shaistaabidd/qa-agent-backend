# Deletes SMS logs older than SmsLog::RETENTION. Run daily via
# `bin/rails sms_logs:purge_expired` (Heroku Scheduler in production).
class PurgeExpiredSmsLogsJob < ApplicationJob
  queue_as :maintenance

  def perform
    SmsLog.expired.in_batches.delete_all
  end
end

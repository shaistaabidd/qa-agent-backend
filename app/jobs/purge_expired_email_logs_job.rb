# Deletes email logs older than EmailLog::RETENTION. Run daily via
# `bin/rails email_logs:purge_expired` (Heroku Scheduler in production).
class PurgeExpiredEmailLogsJob < ApplicationJob
  queue_as :maintenance

  def perform
    EmailLog.expired.in_batches.delete_all
  end
end

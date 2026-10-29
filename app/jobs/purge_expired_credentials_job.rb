# Deletes sessions and one-time codes that can no longer be used. Run daily via
# `bin/rails auth:purge_expired_credentials` (Heroku Scheduler in production).
class PurgeExpiredCredentialsJob < ApplicationJob
  ONE_TIME_PASSWORD_RETENTION = 1.hour

  queue_as :maintenance

  def perform
    Session.expired.in_batches.delete_all
    OneTimePassword.where(expires_at: ...ONE_TIME_PASSWORD_RETENTION.ago).in_batches.delete_all
  end
end

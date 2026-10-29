namespace :sms_logs do
  desc "Delete SMS logs past their retention period (run daily from Heroku Scheduler)"
  task purge_expired: :environment do
    PurgeExpiredSmsLogsJob.perform_now
  end
end

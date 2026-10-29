namespace :email_logs do
  desc "Delete email logs past their retention period (run daily from Heroku Scheduler)"
  task purge_expired: :environment do
    PurgeExpiredEmailLogsJob.perform_now
  end
end

namespace :auth do
  desc "Delete expired sessions and one-time codes (run daily from Heroku Scheduler)"
  task purge_expired_credentials: :environment do
    PurgeExpiredCredentialsJob.perform_now
  end
end

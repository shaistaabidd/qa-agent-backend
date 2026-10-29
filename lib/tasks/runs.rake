namespace :runs do
  desc "Fail runs stuck in running past Run::STALE_AFTER (run every few minutes from Heroku Scheduler)"
  task fail_stale: :environment do
    FailStaleRunsJob.perform_now
  end
end

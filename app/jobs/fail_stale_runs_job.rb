# Fails runs that are still "running" long after they started (Run::STALE_AFTER): the worker
# crashed or never called back, and nothing else would ever close them. Run it every few minutes
# via `bin/rails runs:fail_stale` (Heroku Scheduler in production).
class FailStaleRunsJob < ApplicationJob
  queue_as :maintenance

  def perform
    Run.stale.find_each(&:fail!)
  end
end

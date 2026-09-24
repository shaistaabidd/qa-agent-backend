class RunDispatchJob < ApplicationJob
  queue_as :default

  def perform(run_id)
    run = Run.find(run_id)
    return unless run.queued?

    run.dispatch!
    AgentWorkerClient.new.dispatch(run)
  rescue AgentWorkerClient::ConfigurationError, AgentWorkerClient::DispatchError => e
    run.fail! if run.running?
    Rails.logger.error("RunDispatchJob failed for run #{run_id}: #{e.message}")
  end
end

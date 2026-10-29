module Runs
  # Records what the worker reports at the end of a run: the audit trail, logs and final status.
  # Reporting the status a run already has is a no-op, so a retried callback changes nothing.
  class ReceiveResult < ApplicationService
    STATUS_EVENTS = { "completed" => :complete!, "failed" => :fail!, "blocked" => :block! }.freeze
    MAX_NETWORK_LOG = 2_000

    def initialize(run:, status:, audit_log_entries: [], network_log: nil, summary: nil)
      @run = run
      @status = status.to_s
      @audit_log_entries = Array(audit_log_entries)
      @network_log = network_log
      @summary = summary
    end

    def call
      return success(@run) if @run.status == @status

      Run.transaction do
        persist_audit_log_entries
        persist_logs
        @run.public_send(STATUS_EVENTS.fetch(@status))
      end
      success(@run.reload)
    rescue AASM::InvalidTransition
      failure(:invalid_run_transition)
    end

    private

    def persist_audit_log_entries
      @audit_log_entries.each do |entry|
        @run.audit_log_entries.create!(action_taken: entry[:action_taken], target_element: entry[:target_element])
      end
    end

    def persist_logs
      attributes = {}
      attributes[:network_log] = Array(@network_log).first(MAX_NETWORK_LOG) if @network_log
      attributes[:summary] = @summary.to_h if @summary
      @run.update!(attributes) if attributes.any?
    end
  end
end

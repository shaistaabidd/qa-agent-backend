module Runs
  class ReceiveResult < BaseInteractor
    # NOTE: do not `delegate :run, to: :context` (or define a #run/#run!
    # method) — the interactor gem itself defines #run/#run! as its
    # invocation entry points, and overriding them makes #call silently
    # never execute while the context still reports success.

    STATUS_EVENTS = { 'completed' => :complete!, 'failed' => :fail!, 'blocked' => :block! }.freeze

    def call
      persist_audit_log_entries
      apply_transition
      context.run = context.run.reload
    rescue AASM::InvalidTransition => e
      context.fail!(error: e.message)
    end

    private

    def persist_audit_log_entries
      Array(context.audit_log_entries).each do |entry|
        context.run.audit_log_entries.create!(action_taken: entry[:action_taken],
                                              target_element: entry[:target_element])
      end
    end

    def apply_transition
      event = STATUS_EVENTS.fetch(context.status.to_s)
      context.run.public_send(event)
    end
  end
end

module Findings
  class Create < BaseInteractor
    # NOTE: do not `delegate :run, to: :context` — see Runs::ReceiveResult;
    # the interactor gem reserves #run/#run! for its own invocation.

    def call
      create_finding!
      attach_screenshot!
      ClickUpPostJob.perform_later(context.finding.id)
    rescue ActiveRecord::RecordInvalid => e
      context.fail!(error: e.record.errors.full_messages.to_sentence)
    end

    private

    def create_finding!
      context.finding = context.run.findings.create!(
        title: context.title,
        repro_steps: context.repro_steps,
        severity: context.severity
      )
    end

    def attach_screenshot!
      return unless context.screenshot

      # apollo_upload_server wraps the upload in a DelegateClass, which
      # ActiveStorage's `case attachable; when ActionDispatch::Http::UploadedFile`
      # doesn't recognize via is_a? (delegation isn't inheritance) even though
      # it responds to the same methods. Passing the Hash form sidesteps that
      # class check entirely — io: only needs to respond to #read.
      context.finding.screenshot.attach(
        io: context.screenshot,
        filename: context.screenshot.original_filename,
        content_type: context.screenshot.content_type
      )
    end
  end
end

module Findings
  # Records one issue the worker found during a run, with its screenshot when it sent one.
  class Create < ApplicationService
    def initialize(run:, screenshot: nil, **attributes)
      @run = run
      @screenshot = screenshot
      @attributes = attributes.slice(:title, :repro_steps, :severity, :category).merge(
        details: attributes[:details].to_h, fingerprint: attributes[:fingerprint].presence || attributes[:title]
      )
    end

    def call
      finding = @run.findings.build(@attributes)
      finding.screenshot.attach(@screenshot) if @screenshot
      return failure(:validation_failed, record: finding) unless finding.save

      ClickUpPostJob.perform_later(finding.id)
      success(finding)
    end
  end
end

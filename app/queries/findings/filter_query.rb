module Findings
  # A project's findings, narrowed by the list filters. Grouped (the default) it returns one row per
  # issue, its latest occurrence, unless a single run was asked for.
  class FilterQuery
    def initialize(project)
      @project = project
    end

    def call(grouped: true, run_id: nil, severity: nil, category: nil, source: nil)
      findings = Finding.joins(:run).where(runs: { project_id: @project.id })
      findings = findings.where(run_id:) if run_id
      findings = latest_per_issue(findings) if grouped && run_id.blank?
      findings = findings.where(severity:) if severity
      findings = findings.where(category:) if category.present?
      findings = findings.from_source(source) if source
      findings.with_attached_screenshot.order(created_at: :desc, id: :desc)
    end

    # The latest finding of every issue (DISTINCT ON the same key IssueStats groups by).
    def self.latest_per_issue(findings)
      latest_ids = findings.select("DISTINCT ON (#{IssueStats::KEY}) findings.id")
                           .reorder(Arel.sql("#{IssueStats::KEY}, findings.created_at DESC"))
      Finding.where(id: latest_ids)
    end

    private

    def latest_per_issue(findings) = self.class.latest_per_issue(findings)
  end
end

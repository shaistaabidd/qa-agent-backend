module Findings
  # Counts open issues (one per fingerprint, latest occurrence, not resolved) so the numbers match
  # the issues list instead of adding up every finding from every run.
  class Summary
    def initialize(project)
      @project = project
    end

    def call
      findings = Finding.joins(:run).where(runs: { project_id: @project.id })
      issues = FilterQuery.latest_per_issue(findings).to_a
      open_issues = without_resolved(issues)

      { total: open_issues.size, resolved: issues.size - open_issues.size, total_findings: findings.count,
        by_severity: by_severity(open_issues) }.merge(click_up_counts(open_issues))
    end

    private

    def without_resolved(issues)
      stats = IssueStats.new(@project).call
      issues.reject { stats.dig(it.fingerprint || it.title, :status) == "resolved" }
    end

    def by_severity(open_issues)
      counts = open_issues.group_by(&:severity).transform_values(&:size)
      Finding.severities.keys.map { |severity| { severity:, count: counts.fetch(severity, 0) } }
    end

    def click_up_counts(open_issues)
      posted = open_issues.count(&:clickup_task_id)
      { posted_to_click_up: posted, pending_click_up: open_issues.size - posted }
    end
  end
end

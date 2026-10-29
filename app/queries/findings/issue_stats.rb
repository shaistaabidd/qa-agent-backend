module Findings
  # Sentry-style issue stats: findings with the same fingerprint across a project's runs are one
  # issue. Two grouped queries cover the whole project, keyed by fingerprint (or title, for older
  # findings).
  #
  # A run only counts as evidence about an issue if the issue was found in that run or the run
  # reached the issue's view (page and tab, recorded by the worker), so a run that crashed early or
  # never opened that tab can't "resolve" it. Runs from before views were recorded count as covering
  # everything.
  class IssueStats
    KEY = "COALESCE(findings.fingerprint, findings.title)".freeze

    def initialize(project)
      @project = project
    end

    # => { key => { times_seen:, first_seen_at:, last_seen_at:, status: } }
    def call
      runs = @project.runs.where(status: %i[completed blocked]).order(:id)
                     .pluck(:id, Arel.sql("summary->'views'"))
                     .map { |id, views| [id, views && Array(views)] }

      rows.to_h do |key, run_ids, view, first_seen_at, last_seen_at|
        [key, {
          times_seen: run_ids.size,
          first_seen_at:,
          last_seen_at:,
          status: status(run_ids.sort, relevant_runs(runs, run_ids, view))
        }]
      end
    end

    private

    def rows
      Finding.joins(:run).where(runs: { project_id: @project.id })
             .group(Arel.sql(KEY))
             .pluck(Arel.sql(
                      "#{KEY}, ARRAY_AGG(DISTINCT findings.run_id), " \
                      "(ARRAY_AGG(findings.details->>'view' ORDER BY findings.created_at DESC))[1], " \
                      "MIN(findings.created_at), MAX(findings.created_at)"
                    ))
    end

    def relevant_runs(runs, run_ids, view)
      runs.select { |id, views| run_ids.include?(id) || views.nil? || view.nil? || views.include?(view) }.map(&:first)
    end

    # resolved:  a later run reached its view and it didn't happen
    # regressed: it's back in the latest run after a run where it didn't happen
    #            (only for that run: if it keeps happening it's ongoing again)
    # new:       seen in exactly one run, the latest
    # ongoing:   still happening across runs
    def status(run_ids, relevant)
      latest = relevant.last
      previous = relevant[-2]
      return "resolved" if latest && run_ids.exclude?(latest)
      return "regressed" if previous && run_ids.exclude?(previous) && run_ids.any? { it < previous }

      run_ids.size == 1 ? "new" : "ongoing"
    end
  end
end

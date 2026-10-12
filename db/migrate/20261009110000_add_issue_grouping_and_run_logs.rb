class AddIssueGroupingAndRunLogs < ActiveRecord::Migration[7.0]
  def change
    # Same fingerprint = same issue, across runs (Sentry-style grouping).
    add_column :findings, :fingerprint, :string
    add_index :findings, :fingerprint

    # Every API call a run made, and its performance/memory summary.
    add_column :runs, :network_log, :jsonb, null: false, default: []
    add_column :runs, :summary, :jsonb, null: false, default: {}
  end
end

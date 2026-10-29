class CreateRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :runs do |t|
      t.references :project, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :scope_feature, null: false, foreign_key: { on_delete: :cascade }
      t.string :role_name, null: false
      # 0 queued, 1 running, 2 blocked, 3 completed, 4 failed (see Run).
      t.integer :status, null: false, default: 0
      t.datetime :started_at
      t.datetime :finished_at
      t.jsonb :network_log, null: false, default: []
      t.jsonb :summary, null: false, default: {}
      t.timestamps

      t.index %i[project_id created_at id]
      t.index %i[project_id status]
      # Lets the stale-run reaper find runs that are still running without scanning the table.
      t.index :started_at, where: "status = 1", name: "index_runs_on_started_at_while_running"
    end
  end
end

class CreateFindings < ActiveRecord::Migration[8.1]
  def change
    create_table :findings do |t|
      t.references :run, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :title, null: false
      t.jsonb :repro_steps, null: false, default: []
      # 0 low, 1 medium, 2 high, 3 critical (see Finding).
      t.integer :severity, null: false
      t.string :category
      t.jsonb :details, null: false, default: {}
      # Findings with the same fingerprint across runs are one issue.
      t.string :fingerprint
      # Where the problem lives (frontend, backend, network); derived from the evidence on save.
      t.string :source, null: false, default: "frontend"
      t.string :clickup_task_id
      t.timestamps

      t.index %i[run_id title], unique: true
      t.index :fingerprint
      t.index :source
    end
  end
end

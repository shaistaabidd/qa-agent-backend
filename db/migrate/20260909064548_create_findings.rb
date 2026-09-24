class CreateFindings < ActiveRecord::Migration[7.0]
  def change
    create_table :findings do |t|
      t.references :run, null: false, foreign_key: true
      t.string :title, null: false
      t.jsonb :repro_steps, null: false, default: []
      t.string :screenshot_ref
      t.integer :severity, null: false
      t.string :clickup_task_id

      t.timestamps
    end

    add_index :findings, %i[run_id title], unique: true
  end
end

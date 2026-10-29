class CreateAuditLogEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_log_entries do |t|
      t.references :run, null: false, foreign_key: { on_delete: :cascade }
      t.string :action_taken, null: false
      t.string :target_element
      t.timestamps
    end
  end
end

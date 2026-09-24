class CreateAuditLogEntries < ActiveRecord::Migration[7.0]
  def change
    create_table :audit_log_entries do |t|
      t.references :run, null: false, foreign_key: true
      t.string :action_taken, null: false
      t.string :target_element

      t.timestamps
    end
  end
end

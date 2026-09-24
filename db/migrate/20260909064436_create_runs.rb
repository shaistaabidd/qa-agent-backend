class CreateRuns < ActiveRecord::Migration[7.0]
  def change
    create_table :runs do |t|
      t.references :project, null: false, foreign_key: true
      t.references :scope_feature, null: false, foreign_key: true
      t.string :role_name, null: false
      t.integer :status, null: false, default: 0
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end
  end
end

class CreateIntegrations < ActiveRecord::Migration[7.0]
  def change
    create_table :integrations do |t|
      t.references :project, null: false, foreign_key: true
      t.integer :integration_type, null: false
      t.string :scope
      t.string :external_account_id
      t.datetime :connected_at

      t.timestamps
    end

    add_index :integrations, %i[project_id integration_type], unique: true
  end
end

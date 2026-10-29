class CreateIntegrations < ActiveRecord::Migration[8.1]
  def change
    create_table :integrations do |t|
      t.references :project, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.integer :integration_type, null: false
      # The GitHub App installation id, or the ClickUp list id findings are posted into.
      t.string :external_account_id
      t.string :repo_full_name
      t.string :scope
      t.datetime :connected_at
      t.timestamps

      t.index %i[project_id integration_type], unique: true
    end

    # projects and integrations point at each other, so this side is added once both exist. Both
    # tables are brand new and empty here, so the foreign key locks nothing.
    safety_assured do
      add_reference :projects, :repo_connection, foreign_key: { to_table: :integrations, on_delete: :nullify }
    end
  end
end

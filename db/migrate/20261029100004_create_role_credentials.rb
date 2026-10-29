class CreateRoleCredentials < ActiveRecord::Migration[8.1]
  def change
    create_table :role_credentials do |t|
      t.references :project, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :role_name, null: false
      # Encrypted at rest by Active Record encryption; the column name stays generic so a later
      # move to a secrets manager pointer needs no schema change.
      t.text :encrypted_credential_ref, null: false
      t.timestamps

      t.index %i[project_id role_name], unique: true
    end
  end
end

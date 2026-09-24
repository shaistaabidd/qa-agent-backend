class CreateRoleCredentials < ActiveRecord::Migration[7.0]
  def change
    create_table :role_credentials do |t|
      t.references :project, null: false, foreign_key: true
      t.string :role_name, null: false
      t.string :encrypted_credential_ref, null: false

      t.timestamps
    end

    add_index :role_credentials, %i[project_id role_name], unique: true
  end
end

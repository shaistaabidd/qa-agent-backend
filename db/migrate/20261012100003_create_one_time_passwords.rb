class CreateOneTimePasswords < ActiveRecord::Migration[8.1]
  def change
    create_table :one_time_passwords do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.integer :purpose, null: false
      t.string :code_digest, null: false
      t.integer :failed_attempts, null: false, default: 0
      t.datetime :expires_at, null: false, index: true
      t.timestamps

      t.index %i[user_id purpose], unique: true
    end
  end
end

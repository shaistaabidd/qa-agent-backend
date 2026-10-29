class CreateSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :impersonator, foreign_key: { to_table: :users, on_delete: :cascade }
      t.string :token_digest, null: false, index: { unique: true }
      t.string :ip_address
      t.string :user_agent
      t.datetime :expires_at, null: false, index: true
      t.datetime :last_active_at, null: false, index: true
      t.timestamps
    end
  end
end

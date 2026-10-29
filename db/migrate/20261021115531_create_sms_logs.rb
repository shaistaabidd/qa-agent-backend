class CreateSmsLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :sms_logs do |t|
      # Logs outlive the user they were sent to.
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string :recipient, null: false
      t.text :body, null: false
      t.integer :message_type, null: false
      t.integer :status, null: false, default: 0
      t.string :provider_sid
      t.string :error_code
      t.text :error_message
      t.datetime :sent_at
      t.timestamps
      # One searchable string so the admin search is a single trigram-indexed ILIKE.
      t.virtual :search_document, type: :text, stored: true, as: "recipient || ' ' || body"

      t.index %i[created_at id]
      t.index %i[status created_at id]
      t.index %i[message_type created_at id]
      t.index :search_document, using: :gin, opclass: :gin_trgm_ops
      # The welcome SMS goes out once per user, even if two requests race (message_type 0 = welcome).
      t.index :user_id, unique: true, where: "message_type = 0", name: "index_sms_logs_one_welcome_per_user"
    end
  end
end

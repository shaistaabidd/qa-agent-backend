class CreateEmailLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :email_logs do |t|
      t.string :delivery_id, null: false
      t.string :recipient, null: false
      t.string :mailer, null: false
      t.string :mailer_method, null: false
      t.string :subject
      t.text :body
      t.integer :status, null: false
      t.text :error_message
      t.datetime :sent_at
      t.integer :attempts, null: false, default: 1
      t.timestamps
      # One searchable string so the admin search is a single trigram-indexed ILIKE.
      t.virtual :search_document, type: :text, stored: true,
                                  as: "recipient || ' ' || COALESCE(subject, '')"

      t.index :delivery_id, unique: true
      t.index %i[created_at id]
      t.index %i[status created_at id]
      t.index :search_document, using: :gin, opclass: :gin_trgm_ops
    end
  end
end

class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pg_trgm"

    create_table :users do |t|
      t.string :email, null: false, index: { unique: true }
      t.string :unconfirmed_email
      t.string :password_digest
      t.integer :role, null: false, default: 0
      t.string :first_name
      t.string :last_name
      t.references :invited_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.datetime :invitation_sent_at
      t.datetime :invitation_accepted_at
      t.datetime :archived_at
      t.datetime :access_revoked_at
      t.datetime :last_sign_in_at
      t.timestamps
      # One searchable string so the admin search is a single trigram-indexed ILIKE.
      t.virtual :search_document, type: :text, stored: true,
                                  as: "email || ' ' || COALESCE(first_name, '') || ' ' || COALESCE(last_name, '')"

      t.index %i[created_at id]
      t.index %i[role created_at id]
      t.index :search_document, using: :gin, opclass: :gin_trgm_ops
    end
  end
end

class AddIndexToUsersGoogleUid < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :users, :google_uid, unique: true, where: "google_uid IS NOT NULL", algorithm: :concurrently
  end
end

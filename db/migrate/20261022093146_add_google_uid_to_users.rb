class AddGoogleUidToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :google_uid, :string
  end
end

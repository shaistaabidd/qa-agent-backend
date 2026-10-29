class CreateMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :memberships do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :project, null: false, foreign_key: { on_delete: :cascade }
      t.integer :role, null: false, default: 0
      t.timestamps

      t.index %i[user_id project_id], unique: true
    end
  end
end

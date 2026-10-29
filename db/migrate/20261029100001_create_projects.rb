class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.string :name, null: false
      t.string :target_url, null: false
      t.timestamps

      t.index %i[created_at id]
    end
  end
end

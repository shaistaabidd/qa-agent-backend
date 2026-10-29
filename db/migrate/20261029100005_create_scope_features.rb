class CreateScopeFeatures < ActiveRecord::Migration[8.1]
  def change
    create_table :scope_features do |t|
      t.references :project, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :name, null: false
      t.string :route
      t.string :source
      t.boolean :approved, null: false, default: false
      t.timestamps

      t.index %i[project_id name], unique: true
      t.index %i[project_id created_at id]
    end
  end
end

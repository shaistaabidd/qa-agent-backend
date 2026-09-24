class CreateScopeFeatures < ActiveRecord::Migration[7.0]
  def change
    create_table :scope_features do |t|
      t.references :project, null: false, foreign_key: true
      t.string :name, null: false
      t.string :route
      t.string :source
      t.boolean :approved, null: false, default: false

      t.timestamps
    end
  end
end

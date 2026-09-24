class AddUniqueIndexToScopeFeaturesOnProjectAndName < ActiveRecord::Migration[7.0]
  def change
    add_index :scope_features, %i[project_id name], unique: true
  end
end

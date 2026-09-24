class AddRepoFullNameToIntegrations < ActiveRecord::Migration[7.0]
  def change
    add_column :integrations, :repo_full_name, :string
  end
end

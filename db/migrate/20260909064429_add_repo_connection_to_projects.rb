class AddRepoConnectionToProjects < ActiveRecord::Migration[7.0]
  def change
    add_reference :projects, :repo_connection, null: true, foreign_key: { to_table: :integrations }
  end
end

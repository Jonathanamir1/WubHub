class RemoveVisibilityFromWorkspaceAndProject < ActiveRecord::Migration[7.1]
  def change
    remove_column :projects, :visibility, :string
    remove_column :workspaces, :visibility, :string
  end
end

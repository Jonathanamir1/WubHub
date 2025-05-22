class RemovePrivateFromWorkspaces < ActiveRecord::Migration[7.1]
  def change
    remove_column :workspaces, :private, :boolean, default: false
  end
end
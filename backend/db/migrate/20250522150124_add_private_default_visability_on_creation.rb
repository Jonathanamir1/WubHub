class AddPrivateDefaultVisabilityOnCreation < ActiveRecord::Migration[7.1]
  def change
    change_column :workspaces, :visibility, :string, default: 'private'
  end
end

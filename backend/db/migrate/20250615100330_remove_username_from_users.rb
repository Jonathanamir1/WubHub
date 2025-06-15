# Generate this with: rails generate migration RemoveUsernameFromUsers

class RemoveUsernameFromUsers < ActiveRecord::Migration[7.1]
  def change
    remove_index :users, :username if index_exists?(:users, :username)
    remove_column :users, :username, :string
    
    # Make name required now that we don't have username
    change_column_null :users, :name, false
  end
end
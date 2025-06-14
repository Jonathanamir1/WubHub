class CheckSchemaConsistency < ActiveRecord::Migration[7.1]
  def change
    # Check if visibility column exists in workspaces
    unless column_exists?(:workspaces, :visibility)
      add_column :workspaces, :visibility, :string, default: 'private'
    end

    # Check if visibility column exists in projects
    unless column_exists?(:projects, :visibility)
      add_column :projects, :visibility, :string, default: 'private'
    end
    
    # Check if password_digest column exists in users
    unless column_exists?(:users, :password_digest)
      add_column :users, :password_digest, :string
    end
  end
end
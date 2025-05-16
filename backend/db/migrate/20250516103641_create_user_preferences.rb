# backend/db/migrate/20240516000000_create_user_preferences.rb
class CreateUserPreferences < ActiveRecord::Migration[7.0]
  def change
    create_table :user_preferences do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.string :key, null: false
      t.text :value
      
      t.timestamps
    end
    
    # Ensure each user can only have one record per preference key
    add_index :user_preferences, [:user_id, :key], unique: true
    
    # Add a private flag to workspaces table if it doesn't exist
    unless column_exists?(:workspaces, :private)
      add_column :workspaces, :private, :boolean, default: false
    end
  end
end
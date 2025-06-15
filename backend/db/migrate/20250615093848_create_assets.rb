# db/migrate/20250614_create_assets.rb
class CreateAssets < ActiveRecord::Migration[7.1]
  def change
    create_table :assets do |t|
      t.string :filename, null: false
      t.text :path  # Materialized path for efficient queries
      t.bigint :file_size
      t.string :content_type
      t.jsonb :metadata, default: {}
      
      # Associations
      t.references :workspace, null: false, foreign_key: true
      t.references :container, null: true, foreign_key: true
      t.references :user, null: false, foreign_key: true
      
      t.timestamps
    end
    
    # Indexes for performance and uniqueness
    add_index :assets, [:workspace_id, :container_id, :filename], 
              unique: true, 
              name: 'index_assets_on_workspace_container_filename'
    add_index :assets, :path
    add_index :assets, [:workspace_id, :path]
    # Note: user_id index is automatically created by the references
    add_index :assets, :content_type  # For filtering by file type
    add_index :assets, :created_at  # For recent files
  end
end
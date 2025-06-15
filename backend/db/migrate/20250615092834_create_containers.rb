# db/migrate/20250614_create_containers.rb
class CreateContainers < ActiveRecord::Migration[7.1]
  def change
    create_table :containers do |t|
      t.string :name, null: false
      t.text :path  # Materialized path for efficient queries
      t.references :workspace, null: false, foreign_key: true
      t.references :parent_container, null: true, foreign_key: { to_table: :containers }
      t.jsonb :metadata, default: {}
      
      t.timestamps
    end
    
    # Indexes for performance
    add_index :containers, [:workspace_id, :parent_container_id, :name], 
              unique: true, 
              name: 'index_containers_on_workspace_parent_name'
    add_index :containers, :path
    add_index :containers, [:workspace_id, :path]
  end
end
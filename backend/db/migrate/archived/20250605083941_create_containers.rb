class CreateContainers < ActiveRecord::Migration[7.1]
  def change
    create_table :containers do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :parent_container, null: true, foreign_key: { to_table: :containers }
      t.string :name, null: false
      t.string :container_type, null: false
      t.integer :template_level, null: false
      t.jsonb :metadata

      t.timestamps
    end
    
    add_index :containers, [:container_type, :template_level]
  end
end
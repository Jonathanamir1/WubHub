# backend/db/migrate/20250517000001_create_folders.rb
class CreateFolders < ActiveRecord::Migration[7.1]
  def change
    create_table :folders do |t|
      t.string :name, null: false
      t.references :project, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :parent_folder, foreign_key: { to_table: :folders }
      t.string :path
      t.jsonb :metadata

      t.timestamps
    end
    
    add_index :folders, [:project_id, :path], unique: true
  end
end
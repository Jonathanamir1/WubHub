# Generate this migration with:
# rails generate migration SimplifySystemRemoveNonEssentials

class SimplifySystemRemoveNonEssentials < ActiveRecord::Migration[7.1]
  def up
    # Remove folders and all dependent data
    if table_exists?(:audio_files)
      drop_table :audio_files
    end
    
    if table_exists?(:folders)  
      drop_table :folders
    end
    
    # Remove comments
    if table_exists?(:comments)
      drop_table :comments
    end
    
    # Remove user preferences
    if table_exists?(:user_preferences)
      drop_table :user_preferences
    end
    
    # Clean up any orphaned Active Storage attachments if they were used by removed models
    # (Optional - ActiveStorage will handle this, but this ensures cleanup)
    execute <<-SQL
      DELETE FROM active_storage_attachments 
      WHERE record_type IN ('Folder', 'AudioFile')
    SQL
  end

  def down
    # Recreate tables if you need to rollback (simplified versions)
    
    # Recreate folders
    create_table :folders do |t|
      t.string :name, null: false
      t.references :project, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :parent_folder, foreign_key: { to_table: :folders }
      t.string :path
      t.jsonb :metadata
      t.timestamps
    end
    
    # Recreate audio_files  
    create_table :audio_files do |t|
      t.string :filename, null: false
      t.references :folder, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :file_type
      t.integer :file_size
      t.float :duration
      t.jsonb :metadata
      t.string :waveform_data
      t.timestamps
    end
    
    # Recreate comments
    create_table :comments do |t|
      t.text :content
      t.references :user, null: false, foreign_key: true
      t.references :track_version, null: false, foreign_key: true
      t.timestamps
    end
    
    # Recreate user_preferences
    create_table :user_preferences do |t|
      t.references :user, null: false, foreign_key: true
      t.string :key, null: false
      t.text :value
      t.timestamps
    end
  end
end
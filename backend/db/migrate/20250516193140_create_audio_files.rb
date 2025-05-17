# backend/db/migrate/20250517000002_create_audio_files.rb
class CreateAudioFiles < ActiveRecord::Migration[7.1]
  def change
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
    
    add_index :audio_files, [:folder_id, :filename], unique: true
  end
end
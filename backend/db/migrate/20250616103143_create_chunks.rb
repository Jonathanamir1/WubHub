class CreateChunks < ActiveRecord::Migration[7.1]
  def change
    create_table :chunks do |t|
      t.references :upload_session, null: false, foreign_key: true
      t.integer :chunk_number, null: false
      t.bigint :size, null: false
      t.string :checksum
      t.string :status, null: false, default: 'pending'
      t.text :storage_key  # For tracking where chunk is stored (S3 key, etc.)
      t.jsonb :metadata, default: {}

      t.timestamps
    end
    
    # Ensure unique chunk numbers per upload session
    add_index :chunks, [:upload_session_id, :chunk_number], unique: true
    
    # Performance indexes
    add_index :chunks, :status
    add_index :chunks, :checksum
    add_index :chunks, :created_at
    
    # Index for finding chunks by upload session efficiently
    add_index :chunks, [:upload_session_id, :status]
  end
end
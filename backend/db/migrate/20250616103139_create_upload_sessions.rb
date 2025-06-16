class CreateUploadSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :upload_sessions do |t|
      t.string :filename, null: false, limit: 255
      t.bigint :total_size, null: false
      t.integer :chunks_count, null: false
      t.references :workspace, null: false, foreign_key: true
      t.references :container, null: true, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: 'pending'
      t.jsonb :metadata, default: {}

      t.timestamps
    end
    
    # Unique filename per location (workspace + container combination)
    add_index :upload_sessions, [:workspace_id, :container_id, :filename], 
              where: "status IN ('pending', 'uploading', 'assembling')",
              unique: true,
              name: 'index_upload_sessions_unique_filename_per_location'
    
    # Performance indexes
    add_index :upload_sessions, :status
    add_index :upload_sessions, :created_at
    add_index :upload_sessions, [:workspace_id, :status]
    add_index :upload_sessions, [:user_id, :status]
    
    # Index for cleanup queries (finding expired sessions)
    add_index :upload_sessions, [:status, :created_at]
  end
end
class CreateQueueItemsAndUpdateUploadSessions < ActiveRecord::Migration[7.1]
  def change
    # Create queue_items table
    create_table :queue_items do |t|
      # Core associations
      t.references :workspace, null: false, foreign_key: true, index: true
      t.references :user, null: false, foreign_key: true, index: true
      
      # Queue organization
      t.string :batch_id, null: false, index: true
      t.integer :draggable_type, null: false, default: 1  # file=1, folder=0, mixed=2
      t.string :draggable_name, null: false  # Original name of dragged item
      t.text :original_path                  # Preserve source context
      
      # Progress tracking
      t.integer :total_files, null: false, default: 0
      t.integer :completed_files, null: false, default: 0
      t.integer :failed_files, null: false, default: 0
      
      # Status management
      t.integer :status, null: false, default: 0  # pending=0, processing=1, completed=2, failed=3, cancelled=4
      
      # Queue-specific metadata (upload context, client info, etc.)
      t.jsonb :metadata, null: false, default: {}
      
      t.timestamps
    end
    
    # Add queue_item_id to upload_sessions
    add_reference :upload_sessions, :queue_item, null: true, foreign_key: true, index: true
    
    # Indexes for queue operations
    add_index :queue_items, [:workspace_id, :status]
    add_index :queue_items, [:user_id, :status]
    add_index :queue_items, [:batch_id, :status]
    add_index :queue_items, :created_at
    add_index :queue_items, :metadata, using: :gin
    
    # Index for queue operations on upload_sessions
    add_index :upload_sessions, [:queue_item_id, :status]
  end
end
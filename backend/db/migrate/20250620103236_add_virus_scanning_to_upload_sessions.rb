class AddVirusScanningToUploadSessions < ActiveRecord::Migration[7.1]
  def change
    add_column :upload_sessions, :assembled_file_path, :string
    add_column :upload_sessions, :virus_scan_queued_at, :datetime
    add_column :upload_sessions, :virus_scan_completed_at, :datetime
    
    add_index :upload_sessions, :virus_scan_queued_at
    add_index :upload_sessions, :virus_scan_completed_at
    add_index :upload_sessions, :assembled_file_path
  end
end
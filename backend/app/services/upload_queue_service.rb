# app/services/upload_queue_service.rb
class UploadQueueService
  # Custom exceptions
  class InvalidQueueState < StandardError; end
  class InvalidParameters < StandardError; end
  
  attr_reader :workspace, :user
  
  def initialize(workspace:, user:)
    raise ArgumentError, 'workspace is required' if workspace.nil?
    raise ArgumentError, 'user is required' if user.nil?
    
    @workspace = workspace
    @user = user
  end
  
  # Creates a new queue batch with associated upload sessions
  def create_queue_batch(draggable_name: nil, draggable_type: nil, files: nil, container: nil, original_path: nil, metadata: {})
    validate_batch_parameters!(draggable_name, draggable_type, files)
    
    # Generate unique batch ID
    batch_id = SecureRandom.uuid
    
    # Prepare queue metadata
    queue_metadata = {
      upload_source: metadata[:upload_source] || 'unknown',
      client_info: metadata[:client_info] || {},
      original_folder_structure: extract_folder_structure(files),
      created_by_service: 'UploadQueueService'
    }.merge(metadata)
    
    # Create queue item
    queue_item = QueueItem.create!(
      workspace: workspace,
      user: user,
      batch_id: batch_id,
      draggable_name: draggable_name,
      draggable_type: draggable_type,
      original_path: original_path,
      total_files: files.length,
      completed_files: 0,
      failed_files: 0,
      status: :pending,
      metadata: queue_metadata
    )
    
    # Create upload sessions for each file
    create_upload_sessions_for_files(queue_item, files, container)
    
    Rails.logger.info "Created queue batch: #{batch_id} with #{files.length} files"
    queue_item
  end
  
  # Starts processing a pending queue
  def start_queue_processing(queue_item)
    validate_queue_for_processing!(queue_item)
    
    # Handle empty queues immediately
    if queue_item.total_files.zero?
      queue_item.update!(status: :completed)
      Rails.logger.info "Empty queue #{queue_item.batch_id} marked as completed"
      return queue_item
    end
    
    ActiveRecord::Base.transaction do
      # Mark queue as processing
      queue_item.start_processing!
      
      # Start all associated upload sessions  
      queue_item.upload_sessions.where(status: 'pending').find_each do |upload_session|
        upload_session.start_upload!
        Rails.logger.debug "Started upload session: #{upload_session.id}"
      end
    end
    
    Rails.logger.info "Started processing queue: #{queue_item.batch_id}"
    queue_item
  end
  
  # Pauses an active queue by pausing all active upload sessions
  def pause_queue(queue_item)
    validate_queue_exists!(queue_item)
    
    # Pause all active upload sessions
    queue_item.upload_sessions.active.find_each do |upload_session|
      if upload_session.respond_to?(:pause!)
        upload_session.pause!
      else
        # For now, just log - actual pause functionality would need state machine support
        Rails.logger.info "Pausing upload session #{upload_session.id} - would need state machine support"
      end
    end
    
    Rails.logger.info "Paused queue: #{queue_item.batch_id}"
  end
  
  # Cancels a queue and all its active upload sessions
  def cancel_queue(queue_item)
    validate_queue_exists!(queue_item)
    
    ActiveRecord::Base.transaction do
      # Cancel queue item
      queue_item.cancel!
      
      # Cancel all active upload sessions (don't touch completed ones)
      queue_item.upload_sessions.active.find_each do |upload_session|
        upload_session.cancel!
      end
    end
    
    Rails.logger.info "Cancelled queue: #{queue_item.batch_id}"
  end
  
  # Retries failed uploads in a failed queue
  def retry_failed_queue(queue_item)
    validate_queue_exists!(queue_item)
    
    ActiveRecord::Base.transaction do
      # Reset queue status to processing
      queue_item.update!(status: :processing)
      
      # Retry failed upload sessions
      queue_item.upload_sessions.where(status: ['failed', 'cancelled']).find_each do |upload_session|
        if upload_session.respond_to?(:retry!)
          upload_session.retry!
        else
          # For now, just log - actual retry would need proper state machine support
          Rails.logger.info "Retrying upload session #{upload_session.id} - would need state machine support"
        end
      end
    end
    
    Rails.logger.info "Retrying failed queue: #{queue_item.batch_id}"
  end
  
  # Returns comprehensive status of a queue
  def get_queue_status(queue_item)
    validate_queue_exists!(queue_item)
    
    {
      queue_item_id: queue_item.id,
      batch_id: queue_item.batch_id,
      draggable_name: queue_item.draggable_name,
      draggable_type: queue_item.draggable_type,
      status: queue_item.status,
      total_files: queue_item.total_files,
      completed_files: queue_item.completed_files,
      failed_files: queue_item.failed_files,
      pending_files: queue_item.pending_files,
      progress_percentage: queue_item.progress_percentage,
      original_path: queue_item.original_path,
      created_at: queue_item.created_at,
      updated_at: queue_item.updated_at,
      metadata: queue_item.metadata,
      upload_sessions: queue_item.upload_sessions.map do |session|
        {
          id: session.id,
          filename: session.filename,
          status: session.status,
          progress_percentage: session.progress_percentage,
          total_size: session.total_size,
          uploaded_size: session.uploaded_size
        }
      end
    }
  end
  
  # Lists all active queues for the workspace
  def list_active_queues
    QueueItem.where(workspace: workspace)
             .active
             .includes(:upload_sessions)
             .recent
  end
  
  # Lists all queues (active and inactive) for the workspace
  def list_all_queues(limit: 50)
    QueueItem.where(workspace: workspace)
             .includes(:upload_sessions)
             .recent
             .limit(limit)
  end
  
  # Gets queue statistics for the workspace
  def get_workspace_queue_stats
    queue_items = QueueItem.where(workspace: workspace)
    
    {
      total_queues: queue_items.count,
      active_queues: queue_items.active.count,
      completed_queues: queue_items.completed.count,
      failed_queues: queue_items.failed.count,
      total_files_in_queues: queue_items.sum(:total_files),
      completed_files_in_queues: queue_items.sum(:completed_files),
      failed_files_in_queues: queue_items.sum(:failed_files)
    }
  end
  
  def list_queues_by_status(status)
    QueueItem.where(workspace: workspace, status: status)
             .includes(:upload_sessions)
             .recent
  end

  private
  
  def validate_batch_parameters!(draggable_name, draggable_type, files)
    raise ArgumentError, 'draggable_name is required' if draggable_name.blank?
    raise ArgumentError, 'draggable_type is required' if draggable_type.blank?
    raise ArgumentError, 'files is required' if files.nil?
    
    # Validate draggable_type is valid enum value
    valid_types = QueueItem.draggable_types.keys.map(&:to_sym)
    unless valid_types.include?(draggable_type.to_sym)
      raise ArgumentError, "draggable_type must be one of: #{valid_types.join(', ')}"
    end
  end
  
  def validate_queue_for_processing!(queue_item)
    validate_queue_exists!(queue_item)
    
    unless queue_item.pending?
      raise InvalidQueueState, "Queue item must be in pending state to start processing. Current state: #{queue_item.status}"
    end
  end
  
  def validate_queue_exists!(queue_item)
    raise ArgumentError, 'queue_item is required' if queue_item.nil?
    
    # Ensure queue belongs to this service's workspace and user
    unless queue_item.workspace == workspace && queue_item.user == user
      raise InvalidParameters, 'Queue item does not belong to the specified workspace and user'
    end
  end
  
  def create_upload_sessions_for_files(queue_item, files, container)
    upload_sessions = files.map do |file_info|
      # Skip files with zero size (like folder placeholders)
      next if file_info[:size] == 0 && file_info[:type] == 'folder'
      
      # Ensure minimum file size for upload sessions
      file_size = [file_info[:size], 1].max
      
      # Calculate chunks needed for this file
      chunks_count = calculate_chunks_count(file_size)
      
      # Build upload session attributes
      upload_session_attrs = {
        workspace: workspace,
        user: user,
        queue_item: queue_item,
        container: container,
        filename: file_info[:name],
        total_size: file_size,
        chunks_count: chunks_count,
        status: 'pending',
        metadata: {
          original_path: file_info[:path],
          file_type: file_info[:type] || determine_file_type(file_info[:name]),
          created_by_service: 'UploadQueueService',
          queue_context: {
            batch_id: queue_item.batch_id,
            draggable_name: queue_item.draggable_name
          }
        }
      }
      
      UploadSession.create!(upload_session_attrs)
    end.compact # Remove nil values from skipped folders
    
    Rails.logger.debug "Created #{upload_sessions.length} upload sessions for queue #{queue_item.batch_id}"
    upload_sessions
  end
  
  def calculate_chunks_count(file_size)
    return 1 if file_size <= 1.megabyte
    
    # Use same logic as existing upload system
    chunk_size = case file_size
                when 0..10.megabytes
                  1.megabyte
                when 10.megabytes..100.megabytes
                  5.megabytes
                when 100.megabytes..1.gigabyte
                  10.megabytes
                else
                  25.megabytes
                end
    
    (file_size.to_f / chunk_size).ceil
  end
  
  def determine_file_type(filename)
    extension = File.extname(filename).downcase
    
    case extension
    when '.mp3', '.wav', '.flac', '.aac', '.m4a'
      'audio'
    when '.mp4', '.mov', '.avi', '.mkv'
      'video'
    when '.jpg', '.jpeg', '.png', '.gif', '.bmp'
      'image'
    when '.pdf'
      'document'
    when '.zip', '.rar', '.7z'
      'archive'
    else
      'unknown'
    end
  end
  
  def extract_folder_structure(files)
    # Extract unique directory paths from file paths
    directories = files.map { |file| File.dirname(file[:path] || '') }
                      .uniq
                      .reject { |dir| dir == '.' || dir == '/' }
                      .sort
    
    # Limit to prevent metadata bloat
    directories.take(50)
  end
end
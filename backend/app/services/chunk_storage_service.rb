class ChunkStorageService
  # Custom exceptions
  class StorageError < StandardError; end
  class ChunkNotFoundError < StandardError; end
  
  attr_reader :base_path
  
  def initialize(base_path: nil)
    @base_path = base_path || Rails.root.join('tmp', 'wubhub_chunks')
    ensure_base_directory_exists
  end
  
  # Store a chunk file and return storage key for later retrieval
  def store_chunk(upload_session, chunk_number, chunk_file)
    validate_params(upload_session, chunk_number, chunk_file)
    
    begin
      # Generate file path
      file_path = generate_file_path(upload_session, chunk_number)
      
      # Ensure directory exists
      FileUtils.mkdir_p(File.dirname(file_path))
      
      # Store the chunk file
      File.open(file_path, 'wb') do |file|
        chunk_file.rewind
        IO.copy_stream(chunk_file, file)
      end
      
      # Reset chunk_file position for potential re-use
      chunk_file.rewind
      
      # Return the file path as storage key
      file_path
      
    rescue Errno::EACCES => e
      raise StorageError, "Permission denied: #{e.message}"
    rescue Errno::ENOSPC => e
      raise StorageError, "No space left on device: #{e.message}"
    rescue => e
      raise StorageError, "Failed to store chunk: #{e.message}"
    end
  end
  
  # Check if a chunk exists
  def chunk_exists?(storage_key)
    return false if storage_key.blank?
    File.exist?(storage_key) && File.file?(storage_key)
  end
  
  # Read chunk content as IO object
  def read_chunk(storage_key)
    raise ArgumentError, "Storage key cannot be blank" if storage_key.blank?
    
    unless chunk_exists?(storage_key)
      raise ChunkNotFoundError, "Chunk not found: #{storage_key}"
    end
    
    begin
      File.open(storage_key, 'rb')
    rescue => e
      raise StorageError, "Failed to read chunk: #{e.message}"
    end
  end
  
  # Delete a single chunk
  def delete_chunk(storage_key)
    return false if storage_key.blank?
    return false unless chunk_exists?(storage_key)
    
    begin
      File.delete(storage_key)
      true
    rescue Errno::EACCES => e
      raise StorageError, "Permission denied deleting chunk: #{e.message}"
    rescue => e
      raise StorageError, "Failed to delete chunk: #{e.message}"
    end
  end
  
  # Clean up all chunks for an upload session
  def cleanup_session_chunks(upload_session)
    raise ArgumentError, "Upload session cannot be nil" if upload_session.nil?
    
    deleted_count = 0
    
    # Get all chunks for this session that have storage keys
    chunks_with_storage = upload_session.chunks.where.not(storage_key: [nil, ''])
    
    chunks_with_storage.find_each do |chunk|
      begin
        if delete_chunk(chunk.storage_key)
          deleted_count += 1
        end
      rescue => e
        Rails.logger.warn "Failed to delete chunk #{chunk.storage_key}: #{e.message}"
        # Continue with other chunks
      end
    end
    
    # Try to remove session directory if empty
    cleanup_session_directory(upload_session.id)
    
    deleted_count
  end
  
  # Get storage statistics
  def storage_stats
    stats = {
      backend_type: 'local_filesystem',
      base_path: base_path.to_s,
      total_chunks: 0,
      total_size: 0
    }
    
    chunks_pattern = File.join(base_path, '**', 'chunk_*.tmp')
    
    Dir.glob(chunks_pattern).each do |file_path|
      next unless File.file?(file_path)
      
      stats[:total_chunks] += 1
      stats[:total_size] += File.size(file_path)
    end
    
    stats
  rescue => e
    Rails.logger.error "Error calculating storage stats: #{e.message}"
    stats
  end
  
  def backend_type
    'local_filesystem'
  end
  
  private
  
  def validate_params(upload_session, chunk_number, chunk_file)
    raise ArgumentError, "Upload session cannot be nil" if upload_session.nil?
    raise ArgumentError, "Chunk number must be positive" if chunk_number.nil? || chunk_number <= 0
    raise ArgumentError, "Chunk file cannot be nil" if chunk_file.nil?
  end
  
  def generate_file_path(upload_session, chunk_number)
    # Create path: tmp/wubhub_chunks/session_123/chunk_1.tmp
    session_dir = File.join(base_path, "session_#{upload_session.id}")
    File.join(session_dir, "chunk_#{chunk_number}.tmp")
  end
  
  def cleanup_session_directory(session_id)
    session_dir = File.join(base_path, "session_#{session_id}")
    
    return unless Dir.exist?(session_dir)
    
    # Remove directory if it's empty
    begin
      Dir.rmdir(session_dir) if Dir.empty?(session_dir)
    rescue => e
      Rails.logger.debug "Could not remove session directory #{session_dir}: #{e.message}"
    end
  end
  
  def ensure_base_directory_exists
    FileUtils.mkdir_p(base_path) unless Dir.exist?(base_path)
  rescue => e
    raise StorageError, "Cannot create base storage directory: #{e.message}"
  end
  
  # 🚀 MIGRATION HELPER: When you switch to S3, replace the methods above with:
  #
  # def store_chunk(upload_session, chunk_number, chunk_file)
  #   storage_key = generate_s3_key(upload_session, chunk_number)
  #   s3_client.put_object(bucket: bucket_name, key: storage_key, body: chunk_file)
  #   storage_key
  # end
  #
  # def chunk_exists?(storage_key)
  #   s3_client.head_object(bucket: bucket_name, key: storage_key)
  #   true
  # rescue Aws::S3::Errors::NotFound
  #   false
  # end
  #
  # def read_chunk(storage_key)
  #   s3_client.get_object(bucket: bucket_name, key: storage_key).body
  # end
  #
  # def delete_chunk(storage_key)
  #   s3_client.delete_object(bucket: bucket_name, key: storage_key)
  #   true
  # rescue => e
  #   false
  # end
end
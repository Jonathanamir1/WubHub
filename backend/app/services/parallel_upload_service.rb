class ParallelUploadService
  # Custom exceptions
  class InvalidSessionState < StandardError; end
  
  attr_reader :upload_session, :max_concurrent_uploads
  
  def initialize(upload_session, max_concurrent: 3)
    raise ArgumentError, 'Upload session cannot be nil' if upload_session.nil?
    
    @upload_session = upload_session
    @max_concurrent_uploads = max_concurrent
    @mutex = Mutex.new
  end
  
  # Main method for uploading chunks in parallel
  def upload_chunks_parallel(chunk_data)
    validate_session_state!
    validate_chunk_data!(chunk_data)
    
    # Use concurrent-ruby for thread pool management
    results = []
    
    # Process chunks in batches based on concurrency limit
    chunk_data.each_slice(max_concurrent_uploads) do |chunk_batch|
      batch_results = process_chunk_batch(chunk_batch)
      results.concat(batch_results)
    end
    
    results
  end
  
  # Get current upload status and progress
  def upload_status
    chunks = upload_session.chunks.includes(:upload_session)
    completed_chunks = chunks.where(status: 'completed')
    failed_chunks = chunks.where(status: 'failed')
    pending_chunks = chunks.where(status: 'pending')
    
    completed_chunk_numbers = completed_chunks.pluck(:chunk_number)
    all_chunk_numbers = (1..upload_session.chunks_count).to_a
    chunks_ready_for_upload = all_chunk_numbers - completed_chunk_numbers
    
    {
      total_chunks: upload_session.chunks_count,
      completed_chunks: completed_chunks.count,
      failed_chunks: failed_chunks.count,
      pending_chunks: pending_chunks.count,
      progress_percentage: upload_session.progress_percentage,
      upload_session_status: upload_session.status,
      chunks_ready_for_upload: chunks_ready_for_upload
    }
  end
  
  # Retry only failed chunks
  def retry_failed_chunks(chunk_data)
    failed_chunk_numbers = upload_session.chunks.where(status: 'failed').pluck(:chunk_number)
    
    # Filter chunk_data to only include failed chunks
    failed_chunks_data = chunk_data.select do |chunk_info|
      failed_chunk_numbers.include?(chunk_info[:chunk_number])
    end
    
    upload_chunks_parallel(failed_chunks_data)
  end
  
  private
  
  # Process a batch of chunks concurrently
  def process_chunk_batch(chunk_batch)
    threads = []
    results = []
    results_mutex = Mutex.new
    
    chunk_batch.each do |chunk_info|
      threads << Thread.new do
        begin
          result = upload_single_chunk(chunk_info)
          
          results_mutex.synchronize do
            results << result
          end
        rescue => e
          results_mutex.synchronize do
            results << {
              success: false,
              chunk_number: chunk_info[:chunk_number],
              error: "Upload failed: #{e.message}"
            }
          end
        end
      end
    end
    
    # Wait for all threads in this batch to complete
    threads.each(&:join)
    
    results
  end
  
  # Upload a single chunk (this will call your existing API)
  def upload_single_chunk(chunk_info)
    chunk_number = chunk_info[:chunk_number]
    chunk_data = chunk_info[:data]
    checksum = chunk_info[:checksum]
    size = chunk_info[:size]
    
    Rails.logger.debug "🚀 Uploading chunk #{chunk_number} in parallel"
    
    # Create a temporary file for the chunk data
    temp_file = create_temp_file(chunk_data, chunk_number)
    
    begin
      # Use the existing ChunkStorageService
      storage_service = ChunkStorageService.new
      storage_key = storage_service.store_chunk(upload_session, chunk_number, temp_file)
      
      # Create or update the chunk record
      chunk = upload_session.chunks.find_or_initialize_by(chunk_number: chunk_number)
      chunk.assign_attributes(
        size: size,
        checksum: checksum,
        status: 'completed',
        storage_key: storage_key
      )
      
      # Thread-safe database update
      @mutex.synchronize do
        chunk.save!
        
        # Update upload session state if needed
        if upload_session.status == 'pending'
          upload_session.start_upload!
        end
        
        # Check if all chunks are now completed
        if upload_session.all_chunks_uploaded?
          upload_session.start_assembly!
          
          # Trigger assembly job
          Rails.logger.info "🎯 All chunks uploaded via parallel service! Starting assembly for session #{upload_session.id}"
          UploadAssemblyJob.perform_later(upload_session.id)
        end
      end
      
      {
        success: true,
        chunk_number: chunk_number,
        response: {
          id: chunk.id,
          chunk_number: chunk.chunk_number,
          size: chunk.size,
          checksum: chunk.checksum,
          status: chunk.status,
          storage_key: chunk.storage_key
        }
      }
      
    rescue ChunkStorageService::StorageError => e
      Rails.logger.error "❌ Parallel chunk storage failed for chunk #{chunk_number}: #{e.message}"
      {
        success: false,
        chunk_number: chunk_number,
        error: "Storage failed: #{e.message}"
      }
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "❌ Parallel chunk validation failed for chunk #{chunk_number}: #{e.message}"
      {
        success: false,
        chunk_number: chunk_number,
        error: "Validation failed: #{e.message}"
      }
    rescue StandardError => e
      Rails.logger.error "❌ Parallel chunk upload failed for chunk #{chunk_number}: #{e.message}"
      {
        success: false,
        chunk_number: chunk_number,
        error: "Upload failed: #{e.message}"
      }
    ensure
      # Clean up temporary file
      temp_file&.close
      temp_file&.unlink
    end
  end
  
  # Create a temporary file from chunk data
  def create_temp_file(chunk_data, chunk_number)
    temp_file = Tempfile.new(["parallel_chunk_#{chunk_number}", '.tmp'])
    temp_file.binmode
    temp_file.write(chunk_data)
    temp_file.rewind
    
    # Convert to uploaded file format that Rails expects
    ActionDispatch::Http::UploadedFile.new(
      tempfile: temp_file,
      filename: "chunk_#{chunk_number}.tmp",
      type: 'application/octet-stream'
    )
  end
  
  # Validate that the upload session can accept chunks
  def validate_session_state!
    unless upload_session.status.in?(%w[pending uploading])
      raise InvalidSessionState, "Upload session (#{upload_session.status}) is not accepting chunks"
    end
  end
  
  # Validate chunk data format
  def validate_chunk_data!(chunk_data)
    return if chunk_data.blank?
    
    chunk_data.each do |chunk_info|
      required_keys = [:chunk_number, :data, :size, :checksum]
      missing_keys = required_keys - chunk_info.keys
      
      if missing_keys.any?
        raise ArgumentError, "Invalid chunk data: missing keys #{missing_keys.join(', ')}"
      end
      
      if chunk_info[:chunk_number] < 1 || chunk_info[:chunk_number] > upload_session.chunks_count
        raise ArgumentError, "Invalid chunk number: #{chunk_info[:chunk_number]}"
      end
    end
  end
end
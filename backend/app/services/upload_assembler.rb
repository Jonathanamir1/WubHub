# app/services/upload_assembler.rb
# UPDATED VERSION: Now triggers virus scanning instead of directly completing

class UploadAssembler
  # Custom exception for assembly errors
  class AssemblyError < StandardError; end
  
  def initialize(upload_session)
    @upload_session = upload_session
    @storage_service = ChunkStorageService.new
  end
  
  def assemble!
    validate_assembly_preconditions!
    
    begin
      # Assemble chunks into a single file and store the path
      assembled_file_path = assemble_chunks_to_file
      
      # Store the assembled file path in the upload session
      upload_session.update!(assembled_file_path: assembled_file_path)
      
      # Clean up chunk files AFTER assembly but BEFORE virus scanning
      cleanup_chunk_files
      
      # NEW: Trigger virus scanning instead of completing directly
      Rails.logger.info "🦠 Starting virus scan for assembled file: #{assembled_file_path}"
      scanner_service = VirusScannerService.new
      scanner_service.scan_assembled_file_async(upload_session)
      
      Rails.logger.info "✅ Assembly completed, virus scanning queued for upload session #{upload_session.id}"
      
      # NOTE: We no longer create an Asset here - that happens in FinalizeUploadJob after virus scanning
      # Return the upload_session instead of an asset since we don't create it yet
      upload_session
      
    rescue AssemblyError => e
      # Mark session as failed and re-raise
      upload_session.fail! unless upload_session.status == 'failed'
      raise e
    rescue => e
      # Mark session as failed and wrap in AssemblyError
      upload_session.fail! unless upload_session.status == 'failed'
      raise AssemblyError, "Assembly failed: #{e.message}"
    end
  end
  
  def can_assemble?
    return false unless upload_session.status == 'assembling'
    return false unless all_chunks_present?
    true
  end
  
  def assembly_status
    {
      ready: can_assemble?,
      missing_chunks: missing_chunk_numbers,
      completed_chunks: upload_session.chunks.completed.count,
      total_chunks: upload_session.chunks_count,
      session_status: upload_session.status
    }
  end
  
  private
  
  attr_reader :upload_session, :storage_service
  
  def validate_assembly_preconditions!
    unless upload_session.status == 'assembling'
      upload_session.fail! unless upload_session.status == 'failed'
      raise AssemblyError, "Upload session not ready for assembly. Current status: #{upload_session.status}"
    end
    
    unless all_chunks_present?
      missing = missing_chunk_numbers
      upload_session.fail! unless upload_session.status == 'failed'
      raise AssemblyError, "Upload session not ready for assembly. Missing chunks: #{missing.join(', ')}"
    end
    
    validate_chunk_files_exist!
    validate_no_duplicate_filename!
  end
  
  def all_chunks_present?
    completed_chunk_numbers = upload_session.chunks.completed.pluck(:chunk_number)
    expected_chunks = (1..upload_session.chunks_count).to_a
    (expected_chunks - completed_chunk_numbers).empty?
  end
  
  def missing_chunk_numbers
    completed_chunk_numbers = upload_session.chunks.completed.pluck(:chunk_number)
    expected_chunks = (1..upload_session.chunks_count).to_a
    expected_chunks - completed_chunk_numbers
  end
  
  def validate_chunk_files_exist!
    upload_session.chunks.completed.each do |chunk|
      unless storage_service.chunk_exists?(chunk.storage_key)
        upload_session.fail! unless upload_session.status == 'failed'
        raise AssemblyError, "Upload session not ready for assembly. Chunk file missing: #{chunk.storage_key}"
      end
    end
  end
  
  def validate_no_duplicate_filename!
    existing_asset = Asset.find_by(
      workspace: upload_session.workspace,
      container: upload_session.container,
      filename: upload_session.filename
    )
    
    if existing_asset
      upload_session.fail! unless upload_session.status == 'failed'
      raise AssemblyError, "Upload session not ready for assembly. Filename already exists in this location: #{upload_session.filename}"
    end
  end
  
  def assemble_chunks_to_file
    # Create a temporary file in the assembly directory
    temp_dir = Rails.root.join('tmp', 'assembly')
    FileUtils.mkdir_p(temp_dir)
    
    assembled_file_path = File.join(temp_dir, "assembled_#{upload_session.id}_#{SecureRandom.hex(8)}#{File.extname(upload_session.filename)}")
    
    begin
      total_size = 0
      
      # Get chunks in correct order
      ordered_chunks = upload_session.chunks.completed.order(:chunk_number)
      
      Rails.logger.debug "🔧 Assembling #{ordered_chunks.count} chunks for upload session #{upload_session.id}"
      Rails.logger.debug "🔧 Expected total size: #{upload_session.total_size} bytes"
      Rails.logger.debug "🔧 Assembly file path: #{assembled_file_path}"
      
      File.open(assembled_file_path, 'wb') do |assembled_file|
        ordered_chunks.each do |chunk|
          Rails.logger.debug "🔧 Processing chunk #{chunk.chunk_number}: #{chunk.storage_key}"
          
          # Read chunk using storage service
          chunk_io = storage_service.read_chunk(chunk.storage_key)
          
          begin
            # Copy chunk data to assembled file
            chunk_data = chunk_io.read
            chunk_actual_size = chunk_data.size
            Rails.logger.debug "🔧 Chunk #{chunk.chunk_number} actual size: #{chunk_actual_size} bytes"
            
            assembled_file.write(chunk_data)
            total_size += chunk_actual_size
          ensure
            # Always close the chunk IO
            chunk_io.close if chunk_io.respond_to?(:close)
          end
        end
      end
      
      Rails.logger.debug "🔧 Total assembled size: #{total_size} bytes"
      
      # Validate final file size
      if total_size != upload_session.total_size
        File.delete(assembled_file_path) if File.exist?(assembled_file_path)
        upload_session.fail! unless upload_session.status == 'failed'
        raise AssemblyError, "File size mismatch. Expected: #{upload_session.total_size}, Actual: #{total_size}"
      end
      
      Rails.logger.info "✅ Successfully assembled #{ordered_chunks.count} chunks (#{total_size} bytes) for upload session #{upload_session.id}"
      
      assembled_file_path
      
    rescue => e
      # Clean up assembled file on error
      File.delete(assembled_file_path) if File.exist?(assembled_file_path)
      raise e
    end
  end
  
  def cleanup_chunk_files
    chunks_deleted = storage_service.cleanup_session_chunks(upload_session)
    Rails.logger.info "🧹 Cleaned up #{chunks_deleted} chunk files for upload session #{upload_session.id}"
  end
end
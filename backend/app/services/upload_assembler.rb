# app/services/upload_assembler.rb
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
      # Create the Asset record first
      asset = create_asset
      
      # Assemble chunks into a single file
      assembled_file_path = assemble_chunks_to_file
      
      # Attach the assembled file to the asset
      attach_file_to_asset(asset, assembled_file_path)
      
      # Extract and set file metadata
      extract_file_metadata(asset)
      
      # Clean up chunk files BEFORE marking as completed
      cleanup_chunk_files
      
      # Mark upload session as completed LAST
      upload_session.complete!
      
      # Clean up the temporary assembled file
      File.delete(assembled_file_path) if File.exist?(assembled_file_path)
      
      asset
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
      raise AssemblyError, "Upload session is not ready for assembly. Current status: #{upload_session.status}"
    end
    
    unless all_chunks_present?
      missing = missing_chunk_numbers
      upload_session.fail! unless upload_session.status == 'failed'
      raise AssemblyError, "Missing chunks: #{missing.join(', ')}"
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
      unless chunk.storage_key.present? && storage_service.chunk_exists?(chunk.storage_key)
        upload_session.fail! unless upload_session.status == 'failed'
        raise AssemblyError, "Chunk file not found: #{chunk.storage_key || 'No storage key'}"
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
      raise AssemblyError, "Filename already exists in this location: #{upload_session.filename}"
    end
  end
  
  def create_asset
    Asset.create!(
      filename: upload_session.filename,
      workspace: upload_session.workspace,
      container: upload_session.container,
      user: upload_session.user,
      file_size: 0, # Will be updated after assembly
      content_type: determine_content_type
    )
  end
  
  def determine_content_type
    extension = File.extname(upload_session.filename).downcase
    case extension
    when '.mp3'
      'audio/mpeg'
    when '.wav'
      'audio/wav'
    when '.aiff', '.aif'
      'audio/aiff'
    when '.flac'
      'audio/flac'
    when '.m4a'
      'audio/mp4'
    when '.mp4', '.m4v'
      'video/mp4'
    when '.mov'
      'video/quicktime'
    when '.avi'
      'video/x-msvideo'
    when '.jpg', '.jpeg'
      'image/jpeg'
    when '.png'
      'image/png'
    when '.gif'
      'image/gif'
    when '.pdf'
      'application/pdf'
    when '.zip'
      'application/zip'
    when '.logic'
      'application/octet-stream'
    else
      'application/octet-stream'
    end
  end
  
  def assemble_chunks_to_file
    # Create a temporary file in the same directory as Active Storage will use
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
      
      Rails.logger.debug "🔧 Final assembled size: #{total_size} bytes"
      Rails.logger.debug "🔧 Expected size: #{upload_session.total_size} bytes"
      
      # Validate total size matches expected
      if total_size != upload_session.total_size
        Rails.logger.error "❌ Size mismatch! Expected: #{upload_session.total_size}, Got: #{total_size}"
        File.delete(assembled_file_path) if File.exist?(assembled_file_path)
        raise AssemblyError, "File size mismatch. Expected: #{upload_session.total_size}, Got: #{total_size}"
      end
      
      assembled_file_path
      
    rescue => e
      # Clean up on error
      File.delete(assembled_file_path) if File.exist?(assembled_file_path)
      raise e
    end
  end
  
  def attach_file_to_asset(asset, assembled_file_path)
    Rails.logger.debug "🔧 Attaching file: #{assembled_file_path}"
    Rails.logger.debug "🔧 File exists: #{File.exist?(assembled_file_path)}"
    Rails.logger.debug "🔧 File size: #{File.size(assembled_file_path)} bytes"
    
    begin
      File.open(assembled_file_path, 'rb') do |file|
        asset.file_blob.attach(
          io: file,
          filename: upload_session.filename,
          content_type: asset.content_type
        )
      end
      
      # Verify attachment succeeded
      unless asset.file_blob.attached?
        raise AssemblyError, "Failed to attach file to asset"
      end
      
      Rails.logger.debug "🔧 File attached successfully"
      
    rescue => e
      Rails.logger.error "❌ Exception during attachment: #{e.message}"
      raise AssemblyError, "Failed to attach file: #{e.message}"
    end
  end
  
  def extract_file_metadata(asset)
    if asset.file_blob.attached?
      # Force analyze the blob to get metadata
      asset.file_blob.analyze unless asset.file_blob.analyzed?
      
      # Update asset with correct metadata
      asset.update!(
        file_size: asset.file_blob.byte_size,
        content_type: asset.file_blob.content_type || asset.content_type
      )
      
      Rails.logger.debug "🔧 File metadata extracted: size=#{asset.file_size}, type=#{asset.content_type}"
    end
  end
  
  def cleanup_chunk_files
    Rails.logger.debug "🧹 Cleaning up chunks for upload session #{upload_session.id}"
    
    deleted_count = 0
    upload_session.chunks.each do |chunk|
      if chunk.storage_key.present?
        begin
          if storage_service.delete_chunk(chunk.storage_key)
            deleted_count += 1
            Rails.logger.debug "🗑️ Deleted chunk: #{chunk.storage_key}"
          end
        rescue => e
          Rails.logger.warn "⚠️ Failed to delete chunk #{chunk.storage_key}: #{e.message}"
        end
      end
    end
    
    Rails.logger.debug "🧹 Deleted #{deleted_count} chunk files"
  end
end
# app/jobs/finalize_upload_job.rb
# Generated with: rails generate job FinalizeUpload
class FinalizeUploadJob < ApplicationJob
  queue_as :default
  
  # Retry failed finalizations
  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  
  def perform(upload_session_id)
    Rails.logger.info "📁 Starting upload finalization for upload session #{upload_session_id}"
    
    upload_session = UploadSession.find(upload_session_id)
    
    # Ensure upload session is in the correct state
    unless upload_session.status == 'finalizing'
      Rails.logger.error "❌ Upload session #{upload_session_id} is not in finalizing status: #{upload_session.status}"
      return
    end
    
    begin
      # Use existing UploadAssembler to create the final Asset
      assembler = UploadAssembler.new(upload_session)
      
      # Move file from temp location to permanent storage and create Asset
      asset = create_final_asset(upload_session, assembler)
      
      # Mark upload as completed
      upload_session.transaction do
        upload_session.update!(
          status: 'completed',
          completed_at: Time.current
        )
        
        # Store reference to created asset
        upload_session.metadata ||= {}
        upload_session.metadata['finalization'] = {
          'asset_id' => asset.id,
          'asset_filename' => asset.filename,
          'finalized_at' => Time.current.iso8601,
          'file_size' => asset.file_size
        }
        upload_session.save!
      end
      
      # Clean up temporary assembled file
      cleanup_temp_file(upload_session.assembled_file_path)
      
      Rails.logger.info "✅ Upload finalization completed for upload session #{upload_session_id}, created asset #{asset.id}"
      
    rescue => e
      Rails.logger.error "❌ Upload finalization failed for upload session #{upload_session_id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # Mark as failed
      upload_session.update!(
        status: 'finalization_failed',
        completed_at: Time.current
      )
      
      upload_session.metadata ||= {}
      upload_session.metadata['finalization'] = {
        'status' => 'failed',
        'error' => e.message,
        'failed_at' => Time.current.iso8601
      }
      upload_session.save!
      
      raise # Re-raise to trigger retry mechanism
    end
  end
  
  private
  
  def create_final_asset(upload_session, assembler)
    # Read the virus-scanned assembled file
    assembled_file_path = upload_session.assembled_file_path
    
    unless File.exist?(assembled_file_path)
      raise "Assembled file not found at #{assembled_file_path}"
    end
    
    # Create Asset record
    asset = Asset.create!(
      filename: upload_session.filename,
      file_size: File.size(assembled_file_path),
      content_type: determine_content_type(upload_session.filename),
      workspace: upload_session.workspace,
      container: upload_session.container,
      user: upload_session.user,
      metadata: build_asset_metadata(upload_session)
    )
    
    # Attach the file using Active Storage
    File.open(assembled_file_path, 'rb') do |file|
      asset.file.attach(
        io: file,
        filename: upload_session.filename,
        content_type: determine_content_type(upload_session.filename)
      )
    end
    
    Rails.logger.info "📁 Created asset #{asset.id} for file: #{upload_session.filename}"
    
    asset
  end
  
  def determine_content_type(filename)
    # Use existing MIME type detection or fallback
    extension = File.extname(filename).downcase.delete('.')
    
    case extension
    when 'mp3' then 'audio/mpeg'
    when 'wav' then 'audio/wav'
    when 'aiff', 'aif' then 'audio/aiff'
    when 'flac' then 'audio/flac'
    when 'm4a' then 'audio/mp4'
    when 'ogg' then 'audio/ogg'
    when 'pdf' then 'application/pdf'
    when 'txt' then 'text/plain'
    when 'jpg', 'jpeg' then 'image/jpeg'
    when 'png' then 'image/png'
    else 'application/octet-stream'
    end
  end
  
  def build_asset_metadata(upload_session)
    metadata = {
      'upload_session_id' => upload_session.id,
      'chunks_count' => upload_session.chunks_count,
      'upload_duration' => calculate_upload_duration(upload_session),
      'virus_scan' => upload_session.metadata&.dig('virus_scan')
    }
    
    # Add any existing metadata from upload session
    if upload_session.metadata.present?
      metadata.merge!(upload_session.metadata.except('virus_scan'))
    end
    
    metadata.compact
  end
  
  def calculate_upload_duration(upload_session)
    return nil unless upload_session.created_at && upload_session.virus_scan_completed_at
    
    (upload_session.virus_scan_completed_at - upload_session.created_at).round(2)
  end
  
  def cleanup_temp_file(file_path)
    return unless file_path && File.exist?(file_path)
    
    begin
      File.delete(file_path)
      Rails.logger.info "🗑️ Cleaned up temporary file: #{file_path}"
    rescue => e
      Rails.logger.warn "⚠️ Failed to cleanup temporary file #{file_path}: #{e.message}"
      # Don't raise - cleanup failures shouldn't break finalization
    end
  end
end
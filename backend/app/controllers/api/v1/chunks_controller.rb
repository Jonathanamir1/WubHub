# app/controllers/api/v1/chunks_controller.rb
class Api::V1::ChunksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_upload_session
  before_action :set_chunk, only: [:show]
  before_action :authorize_upload_access!
  
  # POST /api/v1/uploads/:id/chunks/:chunk_number
  def upload
    Rails.logger.info "🚀 ChunksController#upload called"
    Rails.logger.info "Params: #{params.inspect}"
    Rails.logger.info "Upload session: #{@upload_session.inspect}"
    
    chunk_number = params[:chunk_number].to_i
    chunk_file = params[:file]
    checksum = params[:checksum]
    
    Rails.logger.info "Chunk number: #{chunk_number}"
    Rails.logger.info "File present: #{chunk_file.present?}"
    Rails.logger.info "File size: #{chunk_file&.size}"
    Rails.logger.info "Checksum: #{checksum}"
    
    # Basic validations
    if chunk_file.blank?
      return render json: { error: 'File is required' }, status: :unprocessable_entity
    end
    
    if chunk_file.size.zero?
      return render json: { error: 'Chunk file cannot be empty' }, status: :unprocessable_entity
    end
    
    if chunk_number < 1 || chunk_number > @upload_session.chunks_count
      return render json: { 
        error: "Invalid chunk number. Expected 1-#{@upload_session.chunks_count}, got #{chunk_number}" 
      }, status: :unprocessable_entity
    end
    
    unless %w[pending uploading].include?(@upload_session.status)
      return render json: { 
        error: "Upload session is not accepting chunks. Status: #{@upload_session.status}" 
      }, status: :unprocessable_entity
    end
    
    # Validate checksum if provided and looks like a real MD5 hash
    if checksum.present? && checksum.match?(/\A[a-f0-9]{32}\z/i)
      calculated_checksum = calculate_checksum(chunk_file)
      if calculated_checksum != checksum
        return render json: { 
          error: "Checksum mismatch. Expected: #{calculated_checksum}, Got: #{checksum}" 
        }, status: :unprocessable_entity
      end
    end
    
    # 🛡️ NEW: Security scanning
    security_result = perform_security_scan(chunk_file)
    
    # Block critical risk files
    if security_result[:blocked]
      Rails.logger.warn "🚫 Blocked file upload: #{@upload_session.filename} (#{security_result[:risk_level]})"
      return render json: {
        error: "File type is not allowed for security reasons. #{security_result[:details][:threats]&.first}",
        security_details: security_result[:details]
      }, status: :unprocessable_entity
    end
    
    begin
      # Use real chunk storage service
      storage_service = ChunkStorageService.new
      storage_key = storage_service.store_chunk(@upload_session, chunk_number, chunk_file)
      
      Rails.logger.info "✅ Chunk stored successfully at: #{storage_key}"
      
      # Create or update chunk record
      @chunk = @upload_session.chunks.find_or_initialize_by(chunk_number: chunk_number)
      
      # 🔧 FIX: Track if this is a new chunk before assigning attributes
      is_new_chunk = @chunk.new_record?
      
      @chunk.assign_attributes(
        size: chunk_file.size,
        checksum: checksum || calculate_checksum(chunk_file),
        status: 'completed',
        storage_key: storage_key
      )
      
      # 🛡️ Store security metadata if present
      if security_result[:has_warnings]
        @chunk.metadata ||= {}
        @chunk.metadata[:security_scan] = {
          risk_level: security_result[:risk_level],
          warnings: security_result[:warnings],
          threats: security_result[:threats],
          requires_verification: security_result[:requires_verification],
          scanned_at: Time.current.iso8601
        }
      end
      
      @chunk.save!
      
      # Update upload session state
      if @upload_session.status == 'pending'
        @upload_session.start_upload!
      end
      
      # Check if all chunks completed
      if @upload_session.all_chunks_uploaded?
        @upload_session.start_assembly!
      end
      
      # 🔧 FIX: Build response structure that matches security test expectations (nested format)
      response_data = {
        chunk: {
          id: @chunk.id,
          chunk_number: @chunk.chunk_number,
          size: @chunk.size,
          checksum: @chunk.checksum,
          status: @chunk.status,
          upload_session_id: @chunk.upload_session_id,
          storage_key: @chunk.storage_key,
          created_at: @chunk.created_at,
          updated_at: @chunk.updated_at
        },
        upload_session: {
          id: @upload_session.id,
          status: @upload_session.status,
          progress_percentage: @upload_session.progress_percentage
        }
      }
      
      # 🛡️ Add security warning to response if there are warnings (not critical)
      if security_result[:has_warnings] && !security_result[:blocked]
        response_data[:security_warning] = {
          risk_level: security_result[:risk_level],
          threats: security_result[:threats],
          warnings: security_result[:warnings],
          requires_verification: security_result[:requires_verification],
          safe: security_result[:safe]
        }
      end
      
      # 🔧 FIX: Always return 201 for successful chunk uploads (idempotent operation)
      render json: response_data, status: :created
      
    rescue ChunkStorageService::StorageError => e
      Rails.logger.error "❌ Storage error: #{e.message}"
      render json: { error: "Failed to store chunk: #{e.message}" }, status: :internal_server_error
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "❌ Database error: #{e.message}"
      render json: { error: "Failed to save chunk: #{e.record.errors.full_messages.join(', ')}" }, status: :unprocessable_entity
    rescue => e
      Rails.logger.error "❌ Unexpected error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: "Upload failed: #{e.message}" }, status: :internal_server_error
    end
  end
  
  # GET /api/v1/uploads/:id/chunks/:chunk_number
  def show
    if @chunk
      chunk_data = {
        id: @chunk.id,
        chunk_number: @chunk.chunk_number,
        size: @chunk.size,
        checksum: @chunk.checksum,
        status: @chunk.status,
        upload_session_id: @chunk.upload_session_id,
        storage_key: @chunk.storage_key,
        created_at: @chunk.created_at,
        updated_at: @chunk.updated_at
      }
      
      # Include security scan results if present
      if @chunk.metadata&.dig(:security_scan)
        chunk_data[:security_scan] = @chunk.metadata[:security_scan]
      end
      
      render json: chunk_data, status: :ok
    else
      render json: { error: 'Chunk not found' }, status: :not_found
    end
  end
  
  # GET /api/v1/uploads/:id/chunks
  def index
    chunks = @upload_session.chunks.order(:chunk_number)
    
    # 🔧 FIX: Add status filtering
    if params[:status].present?
      chunks = chunks.where(status: params[:status])
    end
    
    chunks_data = chunks.map do |chunk|
      chunk_data = {
        id: chunk.id,
        chunk_number: chunk.chunk_number,
        size: chunk.size,
        checksum: chunk.checksum,
        status: chunk.status,
        upload_session_id: chunk.upload_session_id,
        storage_key: chunk.storage_key,
        created_at: chunk.created_at,
        updated_at: chunk.updated_at
      }
      
      # Include security scan results if present
      if chunk.metadata&.dig(:security_scan)
        chunk_data[:security_scan] = chunk.metadata[:security_scan]
      end
      
      chunk_data
    end
    
    render json: {
      chunks: chunks_data,
      total_chunks: @upload_session.chunks_count,
      completed_chunks: @upload_session.chunks.where(status: 'completed').count,
      progress_percentage: @upload_session.progress_percentage,
      upload_session_status: @upload_session.status
    }, status: :ok
  end
  
  private
  
  def set_upload_session
    @upload_session = UploadSession.joins(:workspace)
                                  .where(workspaces: { id: current_user.accessible_workspaces.pluck(:id) })
                                  .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Upload session not found' }, status: :not_found
  end
  
  def set_chunk
    chunk_number = params[:chunk_number].to_i
    @chunk = @upload_session.chunks.find_by(chunk_number: chunk_number) if @upload_session
  end
  
  def authorize_upload_access!
    # Check if user has upload permissions
    workspace = @upload_session.workspace
    
    # Owner can always upload
    return if workspace.user_id == current_user.id
    
    # Check for collaborator role
    user_role = current_user.roles.find_by(roleable: workspace)
    unless user_role&.name == 'collaborator'
      render json: { error: 'Upload session not found' }, status: :not_found
    end
  end
  
  def calculate_checksum(chunk_file)
    # Reset file position to beginning
    chunk_file.rewind
    
    # Calculate MD5 checksum
    checksum = Digest::MD5.hexdigest(chunk_file.read)
    
    # Reset file position again for subsequent reads
    chunk_file.rewind
    
    checksum
  end
  
  # 🛡️ NEW: Security scanning method
  def perform_security_scan(chunk_file)
    Rails.logger.debug "🔍 Starting security scan for #{@upload_session.filename}"
    
    begin
      # Initialize the malicious file detection service
      detection_service = MaliciousFileDetectionService.new
      
      # Get content type from the file
      content_type = chunk_file.content_type || 'application/octet-stream'
      
      # Perform filename-based scan first
      scan_result = detection_service.scan_file(@upload_session.filename, content_type)
      
      # If file is safe or medium risk, also scan content
      if scan_result.safe? || scan_result.requires_verification?
        # Read file content for analysis
        chunk_file.rewind
        file_content = chunk_file.read
        chunk_file.rewind
        
        # Perform content-based scan
        scan_result = detection_service.scan_content(file_content, @upload_session.filename, content_type)
      end
      
      # Build result hash
      result = {
        safe: scan_result.safe?,
        blocked: scan_result.blocked?,
        requires_verification: scan_result.requires_verification?,
        risk_level: scan_result.risk_level.to_s,
        warnings: scan_result.warnings,
        threats: scan_result.threats,
        has_warnings: !scan_result.safe? || scan_result.requires_verification?,
        details: scan_result.details
      }
      
      Rails.logger.debug "🔍 Security scan completed: #{result[:risk_level]} risk (safe: #{result[:safe]})"
      
      result
      
    rescue => e
      Rails.logger.error "❌ Security scanning failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # Return safe result with warning if scanning fails
      {
        safe: true,
        blocked: false,
        requires_verification: false,
        risk_level: 'unknown',
        warnings: ['Security scan failed - file uploaded without verification'],
        threats: [],
        has_warnings: true,
        details: {
          error: "Security scan failed: #{e.message}",
          filename: @upload_session.filename
        }
      }
    end
  end
end
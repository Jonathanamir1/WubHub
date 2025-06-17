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
    
    begin
      # 🎯 NEW: Use real chunk storage service instead of placeholder
      storage_service = ChunkStorageService.new
      storage_key = storage_service.store_chunk(@upload_session, chunk_number, chunk_file)
      
      Rails.logger.info "✅ Chunk stored successfully at: #{storage_key}"
      
      # Create or update chunk record
      @chunk = @upload_session.chunks.find_or_initialize_by(chunk_number: chunk_number)
      
      @chunk.assign_attributes(
        size: chunk_file.size,
        checksum: checksum || calculate_checksum(chunk_file),
        status: 'completed',
        storage_key: storage_key
      )
      
      @chunk.save!
      
      # Update upload session state
      if @upload_session.status == 'pending'
        @upload_session.start_upload!
      end
      
      # Check if all chunks completed
      if @upload_session.all_chunks_uploaded?
        @upload_session.start_assembly!
        
        # 🎯 NEW: Trigger assembly job when all chunks are complete
        Rails.logger.info "🚀 All chunks uploaded! Starting assembly job for session #{@upload_session.id}"
        UploadAssemblyJob.perform_later(@upload_session.id)
      end
      
      status_code = @chunk.previously_new_record? ? :created : :ok
      
      render json: {
        id: @chunk.id,
        chunk_number: @chunk.chunk_number,
        size: @chunk.size,
        checksum: @chunk.checksum,
        status: @chunk.status,
        upload_session_id: @chunk.upload_session_id,
        storage_key: @chunk.storage_key, # Include for debugging
        created_at: @chunk.created_at,
        updated_at: @chunk.updated_at
      }, status: status_code
      
    rescue ChunkStorageService::StorageError => e
      Rails.logger.error "❌ Chunk storage failed: #{e.message}"
      render json: { error: "Failed to store chunk: #{e.message}" }, status: :internal_server_error
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "❌ Chunk validation failed: #{e.message}"
      render json: { error: "Failed to save chunk: #{e.message}" }, status: :unprocessable_entity
    rescue StandardError => e
      Rails.logger.error "❌ Chunk upload failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: "Failed to process chunk: #{e.message}" }, status: :internal_server_error
    end
  end
  
  # GET /api/v1/uploads/:id/chunks/:chunk_number
  def show
    if @chunk
      render json: {
        id: @chunk.id,
        chunk_number: @chunk.chunk_number,
        size: @chunk.size,
        checksum: @chunk.checksum,
        status: @chunk.status,
        upload_session_id: @chunk.upload_session_id,
        storage_key: @chunk.storage_key, # Include for debugging
        created_at: @chunk.created_at,
        updated_at: @chunk.updated_at
      }, status: :ok
    else
      render json: { error: 'Chunk not found' }, status: :not_found
    end
  end
  
  # GET /api/v1/uploads/:id/chunks
  def index
    chunks = @upload_session.chunks.order(:chunk_number)
    
    # Filter by status if provided
    chunks = chunks.where(status: params[:status]) if params[:status].present?
    
    chunks_data = chunks.map do |chunk|
      {
        id: chunk.id,
        chunk_number: chunk.chunk_number,
        size: chunk.size,
        checksum: chunk.checksum,
        status: chunk.status,
        upload_session_id: chunk.upload_session_id,
        storage_key: chunk.storage_key, # Include for debugging
        created_at: chunk.created_at,
        updated_at: chunk.updated_at
      }
    end
    
    render json: {
      chunks: chunks_data,
      total_chunks: @upload_session.chunks_count,
      completed_chunks: chunks.where(status: 'completed').count,
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
  
  # 🗑️ REMOVED: Old placeholder method
  # def store_chunk_data(chunk_file, chunk_number)
  #   "temp_storage_#{@upload_session.id}_chunk_#{chunk_number}"
  # end
end
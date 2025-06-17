
class Api::V1::UploadsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_workspace, only: [:index, :create]
  before_action :set_upload_session, only: [:show, :update, :destroy]
  before_action :authorize_workspace_access!, only: [:index, :create]
  before_action :authorize_upload_access!, only: [:show, :update, :destroy]

  # FIX #5: Handle JSON parsing errors gracefully
  rescue_from JSON::ParserError do |e|
    render json: { error: 'Invalid JSON format' }, status: :bad_request
  end

  # FIX #6: Handle missing parameters with 422 status
  rescue_from ActionController::ParameterMissing do |e|
    render json: { error: "Missing required parameter: #{e.param}" }, status: :unprocessable_entity
  end

  # GET /api/v1/workspaces/:workspace_id/uploads
  def index
    @upload_sessions = @workspace.upload_sessions.includes(:user, :container, :chunks)
    
    # Filter by status if provided
    @upload_sessions = @upload_sessions.where(status: params[:status]) if params[:status].present?
    
    # Filter by container if provided
    if params[:container_id].present?
      @upload_sessions = @upload_sessions.where(container_id: params[:container_id])
    end
    
    # Basic pagination (if needed)
    if params[:page].present? && params[:per_page].present?
      page = params[:page].to_i
      per_page = [params[:per_page].to_i, 100].min # Max 100 per page
      offset = (page - 1) * per_page
      @upload_sessions = @upload_sessions.offset(offset).limit(per_page)
    end
    
    render json: @upload_sessions, each_serializer: UploadSessionSerializer, status: :ok
  end

  # GET /api/v1/uploads/:id
  def show
    render json: @upload_session, serializer: UploadSessionSerializer, status: :ok
  end

  # POST /api/v1/workspaces/:workspace_id/uploads
  def create
    @upload_session = @workspace.upload_sessions.build(upload_session_params)
    @upload_session.user = current_user

    # Validate container belongs to workspace if provided
    if upload_session_params[:container_id].present?
      container = @workspace.containers.find_by(id: upload_session_params[:container_id])
      unless container
        return render json: { 
          errors: ['Container must belong to the same workspace'] 
        }, status: :unprocessable_entity
      end
    end

    if @upload_session.save
      render json: @upload_session, serializer: UploadSessionSerializer, status: :created
    else
      render json: { errors: @upload_session.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # PUT /api/v1/uploads/:id
  def update
    # Handle state transitions
    if params[:action_type].present?
      handle_state_transition
    else
      # Handle regular attribute updates (like metadata)
      if @upload_session.update(upload_session_update_params)
        render json: @upload_session, serializer: UploadSessionSerializer, status: :ok
      else
        render json: { errors: @upload_session.errors.full_messages }, status: :unprocessable_entity
      end
    end
  rescue UploadSession::InvalidTransition => e
    # FIX #4: Ensure error message includes "Invalid transition"
    error_message = e.message.include?('Invalid transition') ? e.message : "Invalid transition: #{e.message}"
    render json: { error: error_message }, status: :unprocessable_entity
  end

  # DELETE /api/v1/uploads/:id
  def destroy
    @upload_session.destroy
    render json: { message: 'Upload session deleted successfully' }, status: :ok
  end

  private

  def set_workspace
    # FIX #1: Handle outsider access differently
    if current_user.accessible_workspaces.exists?(params[:workspace_id])
      @workspace = current_user.accessible_workspaces.find(params[:workspace_id])
    else
      # Check if workspace exists but user doesn't have access
      if Workspace.exists?(params[:workspace_id])
        @workspace = Workspace.find(params[:workspace_id])
        # This will be caught by authorize_workspace_access!
      else
        render json: { error: 'Workspace not found' }, status: :not_found
        return
      end
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Workspace not found' }, status: :not_found
  end

  def set_upload_session
    # Find upload session through user's accessible workspaces for security
    @upload_session = UploadSession.joins(:workspace)
                                  .where(workspaces: { id: current_user.accessible_workspaces.pluck(:id) })
                                  .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Upload session not found' }, status: :not_found
  end

  def authorize_workspace_access!
    # FIX #1: Return 422 for permission issues during creation
    return if action_name == 'index' && current_user.accessible_workspaces.exists?(@workspace.id)
    
    if action_name == 'create'
      # Check if user has upload permissions
      unless user_can_upload_to_workspace?
        render json: { 
          errors: ['User must have upload permissions for this workspace'] 
        }, status: :unprocessable_entity
        return
      end
    end
  end

  def authorize_upload_access!
    # Access already verified in set_upload_session through accessible_workspaces
  end

  def user_can_upload_to_workspace?
    return true if @workspace.user == current_user
    
    user_role = current_user.roles.find_by(roleable: @workspace)
    user_role&.name == 'collaborator'
  end

  def handle_state_transition
    case params[:action_type]
    when 'start_upload'
      @upload_session.start_upload!
    when 'start_assembly'
      @upload_session.start_assembly!
    when 'complete'
      @upload_session.complete!
    when 'fail'
      @upload_session.fail!
    when 'cancel'
      @upload_session.cancel!
    else
      return render json: { 
        error: 'Invalid action type. Valid actions: start_upload, start_assembly, complete, fail, cancel' 
      }, status: :unprocessable_entity
    end

    render json: @upload_session, serializer: UploadSessionSerializer, status: :ok
  end

  def upload_session_params
    params.require(:upload_session).permit(
      :filename, 
      :total_size, 
      :chunks_count, 
      :container_id,
      metadata: {}
    )
  end

  def upload_session_update_params
    params.require(:upload_session).permit(metadata: {})
  end
end
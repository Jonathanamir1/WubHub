# app/controllers/api/v1/uploads_controller.rb
class Api::V1::UploadsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_workspace, only: [:index, :create]
  before_action :set_upload_session, only: [:show, :update, :destroy]
  before_action :authorize_workspace_access!, only: [:index, :create]
  before_action :authorize_upload_access!, only: [:show, :update, :destroy]

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
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # DELETE /api/v1/uploads/:id
  def destroy
    @upload_session.destroy
    render json: { message: 'Upload session deleted successfully' }, status: :ok
  end

  private

  def set_workspace
    @workspace = current_user.accessible_workspaces.find(params[:workspace_id])
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
    # Access already verified in set_workspace through accessible_workspaces
  end

  def authorize_upload_access!
    # Access already verified in set_upload_session through accessible_workspaces
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
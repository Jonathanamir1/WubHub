class Api::V1::AssetsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_workspace, only: [:index, :create]
  before_action :set_container, only: [:container_assets]
  before_action :set_asset, only: [:show, :update, :destroy, :download]
  before_action :authorize_workspace_access!, only: [:index, :create]
  before_action :authorize_container_access!, only: [:container_assets]
  before_action :authorize_asset_access!, only: [:show, :update, :destroy, :download]

  # GET /api/v1/workspaces/:workspace_id/assets
  def index
    @assets = @workspace.assets.includes(:container, :user, file_blob_attachment: :blob)
    
    # Filter by container if specified
    @assets = @assets.where(container_id: params[:container_id]) if params[:container_id].present?
    
    # Filter by content type if specified
    @assets = @assets.where(content_type: params[:content_type]) if params[:content_type].present?
    
    render json: @assets, each_serializer: AssetSerializer, status: :ok
  end

  # GET /api/v1/containers/:container_id/assets
  def container_assets
    @assets = @container.assets.includes(:user, file_blob_attachment: :blob)
    render json: @assets, each_serializer: AssetSerializer, status: :ok
  end

  # GET /api/v1/assets/:id
  def show
    render json: @asset, serializer: AssetSerializer, status: :ok
  end

  # POST /api/v1/workspaces/:workspace_id/assets
  def create
    @asset = @workspace.assets.build(asset_params)
    @asset.user = current_user

    if @asset.save
      # Handle file upload after successful save
      if params[:file].present?
        begin
          Rails.logger.debug "🔧 Attaching file to asset..."
          
          # Attach the file first
          @asset.file_blob.attach(params[:file])
          
          Rails.logger.debug "🔧 File attached. Extracting metadata..."
          
          # Extract metadata using the model method
          @asset.extract_file_metadata!
          
          Rails.logger.debug "🔧 Metadata extracted successfully"
          
        rescue => e
          Rails.logger.error "❌ Error processing file: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          # Don't fail the request for metadata extraction issues
        end
      end
      
      render json: @asset, serializer: AssetSerializer, status: :created
    else
      render json: { errors: @asset.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/assets/:id
  def update
    # Handle container move - ensure container is in same workspace
    if params[:asset][:container_id].present?
      new_container = @asset.workspace.containers.find(params[:asset][:container_id])
      params[:asset][:container_id] = new_container.id
    end

    if @asset.update(asset_params)
      render json: @asset, serializer: AssetSerializer, status: :ok
    else
      render json: { errors: @asset.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/assets/:id
  def destroy
    @asset.destroy
    render json: { message: 'Asset successfully deleted' }, status: :ok
  end

  # GET /api/v1/assets/:id/download
  def download
    unless @asset.file_blob.attached?
      render json: { error: 'No file attached to this asset' }, status: :not_found
      return
    end

    # Redirect to the file URL for download
    redirect_to rails_blob_url(@asset.file_blob), status: :found
  end

  private

  def set_workspace
    @workspace = current_user.accessible_workspaces.find(params[:workspace_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Workspace not found' }, status: :not_found
  end

  def set_container
    # Find container through user's accessible workspaces
    @container = Container.joins(:workspace)
                         .where(workspaces: { id: current_user.accessible_workspaces.pluck(:id) })
                         .find(params[:container_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Container not found' }, status: :not_found
  end

  def set_asset
    # Find asset through user's accessible workspaces for security
    @asset = Asset.joins(:workspace)
                  .where(workspaces: { id: current_user.accessible_workspaces.pluck(:id) })
                  .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Asset not found' }, status: :not_found
  end

  def authorize_workspace_access!
    # Access already verified in set_workspace
  end

  def authorize_container_access!
    # Access already verified in set_container
  end

  def authorize_asset_access!
    # Access already verified in set_asset
  end

  def asset_params
    params.require(:asset).permit(:filename, :container_id)
  end
end
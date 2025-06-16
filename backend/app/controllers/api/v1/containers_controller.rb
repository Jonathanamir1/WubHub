class Api::V1::ContainersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_workspace, only: [:index, :create, :tree]
  before_action :set_container, only: [:show, :update, :destroy]
  before_action :authorize_workspace_access!, only: [:index, :create]
  before_action :authorize_container_access!, only: [:show, :update, :destroy]
  

  # GET /api/v1/workspaces/:workspace_id/containers
  def index
    @containers = @workspace.containers.includes(:parent_container, :child_containers)
    render json: @containers, status: :ok
  end

  # GET /api/v1/containers/:id
  def show
    render json: @container, status: :ok
  end

  # POST /api/v1/workspaces/:workspace_id/containers
  def create
    @container = @workspace.containers.build(container_params)

    if @container.save
      render json: @container, status: :created
    else
      render json: { errors: @container.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/containers/:id
  def update
    if @container.update(container_params)
      render json: @container, status: :ok
    else
      render json: { errors: @container.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/containers/:id
  def destroy
    @container.destroy
    render json: { message: 'Container deleted successfully' }, status: :ok  # ← Change message
  end

  # GET /api/v1/workspaces/:workspace_id/tree
  def tree
    # Get root-level containers (no parent) with nested data
    @containers = @workspace.containers.includes(:child_containers, :assets).where(parent_container: nil)
    
    # Get root-level assets (no container)
    @assets = @workspace.assets.where(container: nil)
    
    render json: { 
      containers: ActiveModelSerializers::SerializableResource.new(@containers, each_serializer: ContainerSerializer),
      assets: ActiveModelSerializers::SerializableResource.new(@assets, each_serializer: AssetSerializer)
    }, status: :ok
  end

  private

  def set_workspace
    @workspace = current_user.accessible_workspaces.find(params[:workspace_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Workspace not found' }, status: :not_found
  end

  def set_container
    # Find container through user's accessible workspaces for security
    @container = Container.joins(:workspace)
                         .where(workspaces: { id: current_user.accessible_workspaces.pluck(:id) })
                         .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Container not found' }, status: :not_found
  end

  def authorize_workspace_access!
    # Access already verified in set_workspace through accessible_workspaces
  end

  def authorize_container_access!
    # Access already verified in set_container through accessible_workspaces
  end

  def container_params
    params.require(:container).permit(:name, :parent_container_id)
  end
end
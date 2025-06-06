class Api::V1::ContainersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_workspace, only: [:index, :create]

  def index
    @containers = @workspace.containers
    render json: @containers
  end

  def create
    @container = @workspace.containers.build(container_params)

    if @container.save
      render json: @container, status: :created
    else
      render json: { errors: @container.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_workspace
    @workspace = current_user.workspaces.find(params[:workspace_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Workspace not found' }, status: :not_found
  end

  def container_params
    params.require(:container).permit(:name, :container_type, :template_level, :parent_container_id, :metadata)
  end
end
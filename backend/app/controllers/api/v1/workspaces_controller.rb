class Api::V1::WorkspacesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_workspace, only: [:show, :update, :destroy]

  def index
    begin
      @workspaces = current_user.workspaces
      render json: @workspaces, status: :ok
    rescue => e
      Rails.logger.error("Error fetching workspaces: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      render json: { error: 'Failed to load workspaces' }, status: :internal_server_error
    end
  end

  def show
    begin
      render json: @workspace, status: :ok
    rescue => e
      Rails.logger.error("Error fetching workspace: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      render json: { error: 'Failed to load workspace' }, status: :internal_server_error
    end
  end

  def create
    begin
      @workspace = current_user.workspaces.build(workspace_params)

      if @workspace.save
        render json: @workspace, status: :created
      else
        render json: { errors: @workspace.errors.full_messages }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error("Error creating workspace: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      render json: { error: 'Failed to create workspace' }, status: :internal_server_error
    end
  end

  def update
    begin
      if @workspace.user_id == current_user.id && @workspace.update(workspace_params)
        render json: @workspace, status: :ok
      else
        render json: { errors: @workspace.errors.full_messages }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error("Error updating workspace: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      render json: { error: 'Failed to update workspace' }, status: :internal_server_error
    end
  end

  def destroy
    begin
      if @workspace.user_id == current_user.id && @workspace.destroy
        render json: { message: 'Workspace deleted successfully' }, status: :ok
      else
        render json: { errors: ['Failed to delete workspace'] }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error("Error deleting workspace: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      render json: { error: 'Failed to delete workspace' }, status: :internal_server_error
    end
  end

  private

  def set_workspace
    begin
      @workspace = Workspace.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Workspace not found' }, status: :not_found
    end
  end

  def workspace_params
    params.require(:workspace).permit(:name, :description, :workspace_type, :visibility)
  end
end
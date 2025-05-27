# backend/app/controllers/api/v1/projects_controller.rb
class Api::V1::ProjectsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_workspace, only: [:index, :create]
  before_action :set_project, only: [:show, :update, :destroy]

  def index
    @projects = @workspace.projects
    render json: @projects, status: :ok
  end

  def show
    render json: @project, status: :ok
  end

  def recent
    # Get recent projects for the current user
    @projects = current_user.recent_projects(10) # Limit to 10 most recent
    render json: @projects, status: :ok
  end

  def create
    @project = @workspace.projects.build(project_params)
    @project.user = current_user

    if @project.save
      render json: @project, status: :created
    else
      render json: { errors: @project.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @project.update(project_params)
      render json: @project, status: :ok
    else
      render json: { errors: @project.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    if @project.destroy
      render json: { message: 'Project deleted successfully' }, status: :ok
    else
      render json: { errors: ['Failed to delete project'] }, status: :unprocessable_entity
    end
  end

  private

  def set_workspace
    @workspace = current_user.workspaces.find(params[:workspace_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Workspace not found' }, status: :not_found
  end

  def set_project
    @project = current_user.projects.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Project not found' }, status: :not_found
  end
  
  def project_params
    params.require(:project).permit(:title, :description, :visibility, :project_type)
  end
end
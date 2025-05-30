class Api::V1::ProjectsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_workspace, only: [:index, :create]
  before_action :set_project, only: [:show, :update, :destroy]
  before_action :authorize_project_access!, only: [:update, :destroy] 

  def index
    # @workspace is already set and access-checked by set_workspace
    all_projects = @workspace.projects
    accessible_projects = all_projects.select { |project| project.accessible_by?(current_user) }
    
    render json: accessible_projects, status: :ok
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

    
    @workspace = Workspace.find(params[:workspace_id])
    
    unless @workspace.accessible_by?(current_user)
      render json: { error: 'Workspace not found' }, status: :not_found
      return
    end
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: 'Workspace not found' }, status: :not_found
  end

  def set_project
    @project = Project.find(params[:id])
    
    unless @project.accessible_by?(current_user)
      render json: { error: 'Project not found' }, status: :not_found
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Project not found' }, status: :not_found
  end
  
  def project_params
    params.require(:project).permit(:title, :description, :project_type)
  end

  def authorize_project_access!
    # For update/destroy, require ownership or collaborator role
    unless @project.user == current_user || current_user.roles.exists?(roleable: @project, name: ['owner', 'collaborator'])
      render json: { error: 'Project not found' }, status: :not_found
    end
  end
end
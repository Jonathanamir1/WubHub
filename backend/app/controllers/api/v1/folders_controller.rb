# backend/app/controllers/api/v1/folders_controller.rb
class Api::V1::FoldersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project
  before_action :set_folder, only: [:show, :update, :destroy]
  before_action :authorize_access!, only: [:show, :index]
  before_action :authorize_modify!, only: [:create, :update, :destroy]

  # GET /api/v1/projects/:project_id/folders
  def index
    # Root folders only (no parent)
    @folders = @project.folders.where(parent_folder_id: nil)
    render json: @folders, status: :ok
  end

  # GET /api/v1/projects/:project_id/folders/:id
  def show
    render json: @folder, include: ['subfolders', 'audio_files'], status: :ok
  end

  # POST /api/v1/projects/:project_id/folders
  def create
    @folder = @project.folders.build(folder_params)
    @folder.user = current_user

    if @folder.save
      render json: @folder, status: :created
    else
      render json: { errors: @folder.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/projects/:project_id/folders/:id
  def update
    if @folder.update(folder_params)
      render json: @folder, status: :ok
    else
      render json: { errors: @folder.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/projects/:project_id/folders/:id
  def destroy
    @folder.destroy
    render json: { message: 'Folder deleted successfully' }, status: :ok
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Project not found' }, status: :not_found
  end

  def set_folder
    @folder = @project.folders.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Folder not found' }, status: :not_found
  end

  def authorize_access!
    unless @project.user_id == current_user.id || @project.collaborators.include?(current_user)
      render json: { error: 'You do not have permission to access this folder' }, status: :forbidden
    end
  end

  def authorize_modify!
    unless @project.user_id == current_user.id || @project.roles.where(user_id: current_user.id, name: 'editor').exists?
      render json: { error: 'You do not have permission to modify this folder' }, status: :forbidden
    end
  end

  def folder_params
    params.require(:folder).permit(:name, :parent_folder_id, metadata: {})
  end
end
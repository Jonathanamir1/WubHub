# backend/app/controllers/api/v1/audio_files_controller.rb
class Api::V1::AudioFilesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project
  before_action :set_folder
  before_action :set_audio_file, only: [:show, :update, :destroy]
  before_action :authorize_access!, only: [:show, :index]
  before_action :authorize_modify!, only: [:create, :update, :destroy]

  # GET /api/v1/projects/:project_id/folders/:folder_id/audio_files
  def index
    @audio_files = @folder.audio_files
    render json: @audio_files, status: :ok
  end

  # GET /api/v1/projects/:project_id/folders/:folder_id/audio_files/:id
  def show
    render json: @audio_file, status: :ok
  end

  # POST /api/v1/projects/:project_id/folders/:folder_id/audio_files
  def create
    @audio_file = @folder.audio_files.build(audio_file_params)
    @audio_file.project = @project
    @audio_file.user = current_user

    if params[:file].present?
      @audio_file.file.attach(params[:file])
    end

    # Analyze the audio file to extract metadata
    @audio_file.analyze_audio

    if @audio_file.save
      render json: @audio_file, status: :created
    else
      render json: { errors: @audio_file.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/projects/:project_id/folders/:folder_id/audio_files/:id
  def update
    if @audio_file.update(audio_file_params)
      render json: @audio_file, status: :ok
    else
      render json: { errors: @audio_file.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/projects/:project_id/folders/:folder_id/audio_files/:id
  def destroy
    @audio_file.destroy
    render json: { message: 'Audio file deleted successfully' }, status: :ok
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Project not found' }, status: :not_found
  end

  def set_folder
    @folder = @project.folders.find(params[:folder_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Folder not found' }, status: :not_found
  end

  def set_audio_file
    @audio_file = @folder.audio_files.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Audio file not found' }, status: :not_found
  end

  def authorize_access!
    unless @project.user_id == current_user.id || @project.collaborators.include?(current_user)
      render json: { error: 'You do not have permission to access this audio file' }, status: :forbidden
    end
  end

  def authorize_modify!
    unless @project.user_id == current_user.id || @project.roles.where(user_id: current_user.id, name: 'editor').exists?
      render json: { error: 'You do not have permission to modify this audio file' }, status: :forbidden
    end
  end

  def audio_file_params
    params.permit(:filename, :file, metadata: {})
  end
end
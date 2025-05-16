# backend/app/controllers/api/v1/track_versions_controller.rb
class Api::V1::TrackVersionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project, only: [:index, :create]
  before_action :set_track_version, only: [:show, :update, :destroy]
  before_action :authorize_access!, only: [:show]
  before_action :authorize_owner!, only: [:update, :destroy]

  # GET /api/v1/projects/:project_id/track_versions
  def index
    @track_versions = @project.track_versions.order(created_at: :desc)
    render json: @track_versions, status: :ok
  end

  # GET /api/v1/projects/:project_id/track_versions/:id
  def show
    render json: @track_version, status: :ok
  end

  # POST /api/v1/projects/:project_id/track_versions
  def create
    @track_version = @project.track_versions.build(track_version_params)
    @track_version.user = current_user

    if @track_version.save
      render json: @track_version, status: :created
    else
      render json: { errors: @track_version.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/projects/:project_id/track_versions/:id
  def update
    if @track_version.update(track_version_params)
      render json: @track_version, status: :ok
    else
      render json: { errors: @track_version.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/projects/:project_id/track_versions/:id
  def destroy
    @track_version.destroy
    render json: { message: 'Track version deleted successfully' }, status: :ok
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Project not found' }, status: :not_found
  end

  def set_track_version
    @track_version = TrackVersion.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Track version not found' }, status: :not_found
  end

  def authorize_access!
    @project = @track_version.project
    unless @project.user_id == current_user.id || @project.collaborators.include?(current_user)
      render json: { error: 'You do not have permission to view this track version' }, status: :forbidden
    end
  end

  def authorize_owner!
    unless @track_version.user_id == current_user.id || @track_version.project.user_id == current_user.id
      render json: { error: 'You do not have permission to modify this track version' }, status: :forbidden
    end
  end

  def track_version_params
    params.require(:track_version).permit(:title, :description, :waveform_data, metadata: {})
  end
end
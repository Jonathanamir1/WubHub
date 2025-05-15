class Api::V1::TrackVersionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project, only: [:index, :create]
  before_action :set_track_version, only: [:show, :update, :destroy]

  def index
    @track_versions = @project.track_versions
    render json: @track_versions, status: :ok
  end

  def show
    render json: @track_version, status: :ok
  end

  def create
    @track_version = @project.track_versions.build(track_version_params)
    @track_version.user = current_user

    if @track_version.save
      render json: @track_version, status: :created
    else
      render json: { errors: @track_version.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @track_version.user_id == current_user.id && @track_version.update(track_version_params)
      render json: @track_version, status: :ok
    else
      render json: { errors: @track_version.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    if (@track_version.user_id == current_user.id || @track_version.project.user_id == current_user.id) && @track_version.destroy
      render json: { message: 'Track version deleted successfully' }, status: :ok
    else
      render json: { errors: ['Failed to delete track version'] }, status: :unprocessable_entity
    end
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

  def track_version_params
    params.require(:track_version).permit(:title, :waveform_data, metadata: {})
  end
end
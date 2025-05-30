class Api::V1::TrackVersionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project, only: [:index, :create]
  before_action :set_track_version, only: [:show, :update, :destroy]

  # GET /api/v1/projects/:project_id/track_versions
  def index
    # @project is already set and access-checked by set_project
    all_track_versions = @project.track_versions.order(created_at: :desc)
    accessible_track_versions = all_track_versions.select { |tv| tv.accessible_by?(current_user) }
    
    render json: accessible_track_versions, status: :ok
  end
  # GET /api/v1/track_versions/:id
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

  # PATCH/PUT /api/v1/track_versions/:id
  def update
    if @track_version.update(track_version_params)
      render json: @track_version, status: :ok
    else
      render json: { errors: @track_version.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/track_versions/:id
  def destroy
    @track_version.destroy
    render json: { message: 'Track version deleted successfully' }, status: :ok
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
    
    unless @project.accessible_by?(current_user)
      render json: { error: 'Project not found' }, status: :not_found
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Project not found' }, status: :not_found
  end

  def set_track_version
    # Use :id for direct track version routes, :track_version_id for nested routes
    track_version_id = params[:id] || params[:track_version_id]
    @track_version = TrackVersion.find(track_version_id)
    
    unless @track_version.accessible_by?(current_user)
      render json: { error: 'Track version not found' }, status: :not_found
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Track version not found' }, status: :not_found
  end

  def track_version_params
    params.require(:track_version).permit(:title, :description, :waveform_data, metadata: {})
  end
end
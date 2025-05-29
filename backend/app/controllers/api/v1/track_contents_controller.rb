class Api::V1::TrackContentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_track_version, only: [:index, :create]
  before_action :set_track_content, only: [:show, :update, :destroy]

  # GET /api/v1/track_versions/:track_version_id/track_contents
  def index
    @track_contents = @track_version.track_contents
    render json: @track_contents, status: :ok
  end

  # GET /api/v1/track_contents/:id
  def show
    render json: @track_content, status: :ok
  end

  # POST /api/v1/track_versions/:track_version_id/track_contents
  def create
    @track_content = @track_version.track_contents.build(track_content_params)

    if @track_content.save
      if params[:file].present?
        @track_content.file.attach(params[:file])
      end
      render json: @track_content, status: :created
    else
      render json: { errors: @track_content.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/track_contents/:id
  def update
    if @track_content.update(track_content_params)
      render json: @track_content, status: :ok
    else
      render json: { errors: @track_content.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/track_contents/:id
  def destroy
    @track_content.destroy
    render json: { message: 'Content deleted successfully' }, status: :ok
  end

  private

  def set_track_version
    # Only find track versions where user owns the project
    @track_version = current_user.TrackVersion.joins(:project)
                                .where(projects: { user_id: current_user.id })
                                .find(params[:track_version_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Track version not found' }, status: :not_found
  end

  def set_track_content
    # Only find track contents where user owns the project OR the track version
    @track_content = current_user.TrackContent.joins(track_version: :project)
                                .where(
                                  "projects.user_id = ? OR track_versions.user_id = ?",
                                  current_user.id,
                                  current_user.id
                                )
                                .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Content not found' }, status: :not_found
  end

  def track_content_params
    params.require(:track_content).permit(:content_type, :text_content, :title, :description, metadata: {})
  end
end
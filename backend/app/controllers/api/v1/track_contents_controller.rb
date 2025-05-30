class Api::V1::TrackContentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_track_version, only: [:index, :create]
  before_action :set_track_content, only: [:show, :update, :destroy]

  # GET /api/v1/track_versions/:track_version_id/track_contents
  def index
    # @track_version is already set and access-checked by set_track_version
    all_track_contents = @track_version.track_contents
    accessible_track_contents = all_track_contents.select { |tc| tc.accessible_by?(current_user) }
    
    render json: accessible_track_contents, status: :ok
  end

  # GET /api/v1/track_contents/:id
  def show
    render json: @track_content, status: :ok
  end

  # POST /api/v1/track_versions/:track_version_id/track_contents
  def create
    @track_content = @track_version.track_contents.build(track_content_params)
    @track_content.user = current_user  # ← Add this line

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
    @track_version = TrackVersion.find(params[:track_version_id])
    
    unless @track_version.accessible_by?(current_user)
      render json: { error: 'Track version not found' }, status: :not_found
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Track version not found' }, status: :not_found
  end

  def set_track_content
    @track_content = TrackContent.find(params[:id])
    
    unless @track_content.accessible_by?(current_user)
      render json: { error: 'Content not found' }, status: :not_found
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Content not found' }, status: :not_found
  end


  def track_content_params
    params.require(:track_content).permit(:content_type, :text_content, :title, :description, metadata: {})
  end
end
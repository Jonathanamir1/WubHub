class Api::V1::TrackContentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_container, only: [:index, :create]

  def index
    @track_contents = @container.track_contents
    render json: @track_contents
  end

  def create
    @track_content = @container.track_contents.build(track_content_params)
    @track_content.user = current_user

    if @track_content.save
      render json: @track_content, status: :created
    else
      render json: { errors: @track_content.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_container
    @container = Container.joins(:workspace)
                        .where(workspaces: { user_id: current_user.id })
                        .find(params[:container_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Container not found' }, status: :not_found
  end

  def track_content_params
    params.require(:track_content).permit(:title, :description, :content_type, :text_content, :metadata)
  end
end
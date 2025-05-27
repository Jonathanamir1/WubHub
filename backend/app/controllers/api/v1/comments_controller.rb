# app/controllers/api/v1/comments_controller.rb
class Api::V1::CommentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_track_version, only: [:index, :create]
  before_action :set_comment, only: [:show, :update, :destroy]

  # GET /api/v1/track_versions/:track_version_id/comments
  def index
    @comments = @track_version.comments.includes(:user).order(:created_at)
    render json: @comments, status: :ok
  end

  # GET /api/v1/comments/:id
  def show
    render json: @comment, status: :ok
  end

  # POST /api/v1/track_versions/:track_version_id/comments
  def create
    @comment = @track_version.comments.build(comment_params)
    @comment.user = current_user

    if @comment.save
      render json: @comment, status: :created
    else
      render json: { errors: @comment.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/comments/:id
  def update
    if @comment.update(comment_params)
      render json: @comment, status: :ok
    else
      render json: { errors: @comment.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/comments/:id
  def destroy
    @comment.destroy
    render json: { message: 'Comment deleted successfully' }, status: :ok
  end

  private

  def set_track_version
    # Only find track versions where user owns the project
    @track_version = TrackVersion.joins(:project)
                                .where(projects: { user_id: current_user.id })
                                .find(params[:track_version_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Track version not found' }, status: :not_found
  end

  def set_comment
    # Allow access if user owns the comment OR owns the project
    @comment = Comment.joins(track_version: :project)
                     .where(
                       "comments.user_id = ? OR projects.user_id = ?",
                       current_user.id,
                       current_user.id
                     )
                     .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Comment not found' }, status: :not_found
  end

  def comment_params
    params.require(:comment).permit(:content)
  end
end
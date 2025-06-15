class Api::V1::UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user, only: [:show, :update, :destroy]
  before_action :authorize_user!, only: [:update, :destroy]

  # GET /api/v1/users
  def index
    @users = User.all
    
    # Filter by name search if provided
    if params[:search].present?
      @users = @users.where("name ILIKE ?", "%#{params[:search]}%")
    end
    
    render json: @users, each_serializer: UserSerializer, status: :ok
  end

  # GET /api/v1/users/:id
  def show
    render json: @user, serializer: UserSerializer, scope: { current_user: current_user }, status: :ok
  end

  # PUT /api/v1/users/:id
  def update
    # Handle profile image separately if provided
    if params[:profile_image].present?
      @user.profile_image.attach(params[:profile_image])
    end

    if @user.update(user_params)
      render json: @user, serializer: UserSerializer, scope: { current_user: current_user }, status: :ok
    else
      render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/users/:id
  def destroy
    @user.destroy
    render json: { message: 'Account deleted successfully' }, status: :ok
  end

  private

  def set_user
    @user = User.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'User not found' }, status: :not_found
  end

  def authorize_user!
    unless @user == current_user
      error_message = case action_name
                    when 'update'
                      'You can only update your own profile'
                    when 'destroy'
                      'You can only delete your own account'
                    end
      render json: { error: error_message }, status: :forbidden
    end
  end

  def user_params
    params.require(:user).permit(:name, :bio, :email, :password, :password_confirmation)
  end
end
class Api::V1::RolesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project, only: [:index, :create]
  before_action :set_role, only: [:show, :update, :destroy]
  before_action :authorize_owner!

  # GET /api/v1/projects/:project_id/roles
  def index
    @roles = @project.roles.includes(:user)
    render json: @roles, status: :ok
  end

  # GET /api/v1/roles/:id
  def show
    render json: @role, status: :ok
  end

  # POST /api/v1/projects/:project_id/roles
  def create
    @role = @project.roles.build(role_params)

    if @role.save
      render json: @role, status: :created
    else
      render json: { errors: @role.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/roles/:id
  def update
    if @role.update(role_params)
      render json: @role, status: :ok
    else
      render json: { errors: @role.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/roles/:id
  def destroy
    @role.destroy
    render json: { message: 'Role successfully removed' }, status: :ok
  end

  private

  def set_project
    @project = current_user.projects.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Project not found' }, status: :not_found
  end

  def set_role
    # Only find roles for projects owned by current user
    @role = Role.joins("JOIN projects ON roles.roleable_id = projects.id AND roles.roleable_type = 'Project'")
                .where(projects: { user_id: current_user.id })
                .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Role not found' }, status: :not_found
  end

  def authorize_owner!
    # This is handled by set_project and set_role scoping
    # Only project owners can access these endpoints
  end

  def role_params
    params.require(:role).permit(:name, :user_id)
  end
end
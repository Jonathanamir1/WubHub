# backend/app/controllers/api/v1/roles_controller.rb
module Api
  module V1
    class RolesController < ApplicationController
      before_action :authenticate_user!
      before_action :set_project
      before_action :set_role, only: [:show, :update, :destroy]
      before_action :authorize_owner!, only: [:create, :update, :destroy]

      # GET /api/v1/projects/:project_id/roles
      def index
        @roles = @project.roles.includes(:user)
        render json: @roles, status: :ok
      end

      # GET /api/v1/projects/:project_id/roles/:id
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

      # PATCH/PUT /api/v1/projects/:project_id/roles/:id
      def update
        if @role.update(role_params)
          render json: @role, status: :ok
        else
          render json: { errors: @role.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/projects/:project_id/roles/:id
      def destroy
        @role.destroy
        render json: { message: 'Role successfully removed' }, status: :ok
      end

      private

      def set_project
        @project = Project.find(params[:project_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Project not found' }, status: :not_found
      end

      def set_role
        @role = @project.roles.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Role not found' }, status: :not_found
      end

      def authorize_owner!
        unless @project.user_id == current_user.id
          render json: { error: 'Only the project owner can manage roles' }, status: :forbidden
        end
      end

      def role_params
        params.require(:role).permit(:name, :user_id)
      end
    end
  end
end
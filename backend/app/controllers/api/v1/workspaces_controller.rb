# backend/app/controllers/api/v1/workspaces_controller.rb
module Api
  module V1
    class WorkspacesController < ApplicationController
      before_action :authenticate_user!
      before_action :set_workspace, only: [:show, :update, :destroy]
      before_action :authorize_owner!, only: [:show, :update, :destroy]

      # GET /api/v1/workspaces
      def index
        @workspaces = current_user.accessible_workspaces
        render json: @workspaces
      end

      # GET /api/v1/workspaces/:id
      def show
        render json: @workspace
      end

      # POST /api/v1/workspaces
      def create
        @workspace = current_user.workspaces.build(workspace_params)

        if @workspace.save
          render json: @workspace, status: :created
        else
          render json: { errors: @workspace.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PUT/PATCH /api/v1/workspaces/:id
      def update
        if @workspace.update(workspace_params)
          render json: @workspace
        else
          render json: { errors: @workspace.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/workspaces/:id
      def destroy
        @workspace.destroy
        render json: { message: 'Workspace successfully deleted' }
      end

      private

      def set_workspace
        @workspace = current_user.workspaces.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Workspace not found' }, status: :not_found
      end

      def authorize_owner!
        unless @workspace.user_id == current_user.id
          render json: { error: 'You are not authorized to perform this action' }, status: :forbidden
        end
      end

      def workspace_params
        params.require(:workspace).permit(:name, :description)
      end
    end
  end
end
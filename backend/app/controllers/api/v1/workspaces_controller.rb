# backend/app/controllers/api/v1/workspaces_controller.rb
module Api
  module V1
    class WorkspacesController < ApplicationController
      before_action :authenticate_user!
      before_action :set_workspace, only: [:show, :update, :destroy]
      before_action :authorize_owner!, only: [:show, :update, :destroy]

      # GET /api/v1/workspaces
      def index
        # Get user's accessible workspaces
        accessible_workspaces = current_user.accessible_workspaces
        
        # Add public workspaces that aren't already included
        public_workspaces = Workspace.joins(:privacy).where(privacies: { level: 'public' })
        
        # Combine and remove duplicates
        all_workspace_ids = (accessible_workspaces.pluck(:id) + public_workspaces.pluck(:id)).uniq
        @workspaces = Workspace.where(id: all_workspace_ids)
        
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
        @workspace = Workspace.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Workspace not found' }, status: :not_found
      end

      def authorize_owner!
        # For show action, use privacy logic
        if action_name == 'show'
          unless @workspace.accessible_by?(current_user)
            render json: { error: 'Workspace not found' }, status: :not_found
          end
        else
          # For update/destroy, require ownership
          unless @workspace.user_id == current_user.id
            render json: { error: 'Workspace not found' }, status: :not_found  # Hide existence
          end
        end
      end

      def workspace_params
        params.require(:workspace).permit(:name, :description, :workspace_type)  # Add :workspace_type
      end
    end
  end
end
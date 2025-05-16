module Api
  module V1
    class WorkspacePreferencesController < ApplicationController
      before_action :authenticate_user!

      # GET /api/v1/workspace_preferences
      def index
        preferences = current_user.workspace_preferences
        render json: preferences
      end

      # PUT /api/v1/workspace_preferences/update_order
      def update_order
        pref = current_user.find_or_create_preference(UserPreference::WORKSPACE_ORDER)
        
        if pref.update(value: params[:workspace_ids])
          render json: { success: true, workspace_order: pref.value }
        else
          render json: { error: 'Failed to update workspace order' }, status: :unprocessable_entity
        end
      end

      # PUT /api/v1/workspace_preferences/update_favorites
      def update_favorites
        pref = current_user.find_or_create_preference(UserPreference::FAVORITE_WORKSPACES)
        
        if pref.update(value: params[:workspace_ids])
          render json: { success: true, favorite_workspaces: pref.value }
        else
          render json: { error: 'Failed to update favorite workspaces' }, status: :unprocessable_entity
        end
      end

      # PUT /api/v1/workspace_preferences/update_privacy
      def update_privacy
        pref = current_user.find_or_create_preference(UserPreference::PRIVATE_WORKSPACES)
        
        if pref.update(value: params[:workspace_ids])
          render json: { success: true, private_workspaces: pref.value }
        else
          render json: { error: 'Failed to update private workspaces' }, status: :unprocessable_entity
        end
      end

      # PUT /api/v1/workspace_preferences/update_collapsed_sections
      def update_collapsed_sections
        pref = current_user.find_or_create_preference(UserPreference::COLLAPSED_SECTIONS)
        
        if pref.update(value: params[:collapsed_sections])
          render json: { success: true, collapsed_sections: pref.value }
        else
          render json: { error: 'Failed to update collapsed sections' }, status: :unprocessable_entity
        end
      end
    end
  end
end
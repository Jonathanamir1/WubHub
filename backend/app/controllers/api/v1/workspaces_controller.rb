# backend/app/controllers/api/v1/workspace_preferences_controller.rb
module Api
  module V1
    class WorkspacePreferencesController < ApplicationController
      before_action :authenticate_user!
      
      # Update workspace order for current user
      def update_order
        begin
          workspace_ids = params[:workspace_ids]
          
          # Validate that all workspaces belong to user or are shared with them
          unless validate_workspace_access(workspace_ids)
            return render json: { error: "You don't have access to one or more of these workspaces" }, status: :forbidden
          end
          
          # Create or update user preference
          preference = current_user.user_preferences.find_or_initialize_by(key: 'workspace_order')
          preference.value = workspace_ids
          
          if preference.save
            render json: { status: 'success', message: 'Workspace order updated successfully' }
          else
            render json: { error: preference.errors.full_messages.join(', ') }, status: :unprocessable_entity
          end
        rescue => e
          Rails.logger.error("Error in update_order: #{e.message}")
          render json: { error: 'An error occurred while updating workspace order' }, status: :internal_server_error
        end
      end
      
      # Update workspace favorite status
      def update_favorites
        begin
          workspace_ids = params[:workspace_ids]
          
          # Validate that all workspaces belong to user or are shared with them
          unless validate_workspace_access(workspace_ids)
            return render json: { error: "You don't have access to one or more of these workspaces" }, status: :forbidden
          end
          
          # Create or update user preference
          preference = current_user.user_preferences.find_or_initialize_by(key: 'favorite_workspaces')
          preference.value = workspace_ids
          
          if preference.save
            render json: { status: 'success', message: 'Favorite workspaces updated successfully' }
          else
            render json: { error: preference.errors.full_messages.join(', ') }, status: :unprocessable_entity
          end
        rescue => e
          Rails.logger.error("Error in update_favorites: #{e.message}")
          render json: { error: 'An error occurred while updating favorite workspaces' }, status: :internal_server_error
        end
      end
      
      # Update workspace privacy status
      def update_privacy
        begin
          workspace_ids = params[:workspace_ids]
          
          # For privacy, validate that user is the owner of these workspaces
          unless validate_workspace_ownership(workspace_ids)
            return render json: { error: "You can only set privacy for workspaces you own" }, status: :forbidden
          end
          
          # Create or update user preference
          preference = current_user.user_preferences.find_or_initialize_by(key: 'private_workspaces')
          preference.value = workspace_ids
          
          # Also update the actual workspaces' visibility settings
          workspace_ids.each do |ws_id|
            workspace = Workspace.find(ws_id)
            workspace.update(private: true)
          end
          
          # Set all other user workspaces to public
          current_user.owned_workspaces.where.not(id: workspace_ids).update_all(private: false)
          
          if preference.save
            render json: { status: 'success', message: 'Private workspaces updated successfully' }
          else
            render json: { error: preference.errors.full_messages.join(', ') }, status: :unprocessable_entity
          end
        rescue => e
          Rails.logger.error("Error in update_privacy: #{e.message}")
          render json: { error: 'An error occurred while updating private workspaces' }, status: :internal_server_error
        end
      end
      
      # Get user preferences for workspaces
      def index
        begin
          # Fetch all workspace preferences for the current user
          workspace_order = current_user.user_preferences.find_by(key: 'workspace_order')&.value || []
          favorite_workspaces = current_user.user_preferences.find_by(key: 'favorite_workspaces')&.value || []
          private_workspaces = current_user.user_preferences.find_by(key: 'private_workspaces')&.value || []
          collapsed_sections = current_user.user_preferences.find_by(key: 'collapsed_sections')&.value || {
            favorites: false,
            workspaces: false,
            private: false
          }
          
          render json: {
            workspace_order: workspace_order,
            favorite_workspaces: favorite_workspaces,
            private_workspaces: private_workspaces,
            collapsed_sections: collapsed_sections
          }
        rescue => e
          Rails.logger.error("Error in workspace_preferences#index: #{e.message}")
          render json: { error: 'An error occurred while fetching workspace preferences' }, status: :internal_server_error
        end
      end
      
      # Update collapsed sections
      def update_collapsed_sections
        begin
          collapsed_data = params[:collapsed_sections]
          
          # Create or update user preference
          preference = current_user.user_preferences.find_or_initialize_by(key: 'collapsed_sections')
          preference.value = collapsed_data
          
          if preference.save
            render json: { status: 'success', message: 'Collapsed sections updated successfully' }
          else
            render json: { error: preference.errors.full_messages.join(', ') }, status: :unprocessable_entity
          end
        rescue => e
          Rails.logger.error("Error in update_collapsed_sections: #{e.message}")
          render json: { error: 'An error occurred while updating collapsed sections' }, status: :internal_server_error
        end
      end
      
      private
      
      # Validate that user has access to all workspaces
      def validate_workspace_access(workspace_ids)
        return true if workspace_ids.blank?
        
        # Get all workspaces the user has access to
        accessible_workspaces = current_user.accessible_workspaces.pluck(:id).map(&:to_s)
        
        # Check if all requested workspace IDs are accessible
        workspace_ids.all? { |id| accessible_workspaces.include?(id.to_s) }
      end
      
      # Validate that user owns all workspaces
      def validate_workspace_ownership(workspace_ids)
        return true if workspace_ids.blank?
        
        # Get all workspaces owned by the user
        owned_workspaces = current_user.owned_workspaces.pluck(:id).map(&:to_s)
        
        # Check if all requested workspace IDs are owned by the user
        workspace_ids.all? { |id| owned_workspaces.include?(id.to_s) }
      end
    end
  end
end
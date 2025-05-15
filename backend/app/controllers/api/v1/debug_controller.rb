class Api::V1::DebugController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    render json: {
      message: "Debug endpoint working",
      timestamp: Time.now
    }
  end

  def current_user_info
    if current_user
      render json: {
        user_exists: true,
        user_id: current_user.id,
        username: current_user.username,
        email: current_user.email
      }
    else
      render json: {
        user_exists: false,
        auth_header: request.headers['Authorization'],
        error: "No current user"
      }
    end
  end

  def check_workspaces
    if current_user
      begin
        workspaces = current_user.workspaces
        render json: {
          user_id: current_user.id,
          workspaces_count: workspaces.count,
          workspaces_ids: workspaces.pluck(:id),
          first_workspace: workspaces.first.as_json(only: [:id, :name, :workspace_type])
        }
      rescue => e
        render json: {
          error: e.message,
          backtrace: e.backtrace.first(5)
        }
      end
    else
      render json: {
        error: "No current user"
      }
    end
  end
end
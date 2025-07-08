# Health Check Controller
# Place this file in: backend/app/controllers/api/v1/health_controller.rb

class Api::V1::HealthController < ApplicationController
  # Skip authentication for health checks
  skip_before_action :authenticate_user!, only: [:show]

  # GET /api/v1/health
  def show
    health_data = {
      status: 'ok',
      service: 'wubhub-api',
      timestamp: Time.current.iso8601,
      database: database_status,
      redis: redis_status,
      environment: Rails.env
    }

    render json: health_data, status: :ok
  rescue => e
    error_response = {
      status: 'error',
      service: 'wubhub-api',
      timestamp: Time.current.iso8601,
      error: e.message,
      environment: Rails.env
    }

    render json: error_response, status: :service_unavailable
  end

  private

  def database_status
    ActiveRecord::Base.connection.execute('SELECT 1')
    'connected'
  rescue => e
    Rails.logger.error "Database health check failed: #{e.message}"
    'disconnected'
  end

  def redis_status
    Rails.cache.redis.ping
    'connected'
  rescue => e
    Rails.logger.error "Redis health check failed: #{e.message}"
    'disconnected'
  end
end
require 'rails_helper'

RSpec.describe "Api::V1::Health", type: :request do
  describe "GET /api/v1/health" do
    it "returns a successful health check" do
      get "/api/v1/health"
      
      expect(response).to have_http_status(:ok)
      
      json_response = JSON.parse(response.body)
      expect(json_response['status']).to eq('ok')
      expect(json_response['service']).to eq('wubhub-api')
      expect(json_response).to have_key('timestamp')
    end

    it "returns health status without authentication" do
      # Health endpoint should be publicly accessible
      get "/api/v1/health"
      
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')
    end

    it "includes database connectivity check" do
      get "/api/v1/health"
      
      json_response = JSON.parse(response.body)
      expect(json_response['database']).to eq('connected')
    end

    it "includes Redis connectivity check" do
      get "/api/v1/health"
      
      json_response = JSON.parse(response.body)
      expect(json_response['redis']).to eq('not_configured')
    end
  end
end
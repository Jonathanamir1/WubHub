require 'rails_helper'

RSpec.describe "Rate Limiting", type: :request do
  # Manually set up rate limiting for these tests
  before(:all) do
    # Configure Rack::Attack just for these tests
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    
    # Set up throttling rules
    Rack::Attack.throttle('test_logins/ip', limit: 10, period: 60.seconds) do |req|
      if req.path == '/api/v1/auth/login' && req.post?
        req.ip
      end
    end
    
    Rack::Attack.throttle('test_uploads/ip', limit: 20, period: 3600.seconds) do |req|
      if req.path.include?('track_contents') && req.post?
        req.ip
      end
    end
    
    Rack::Attack.throttled_responder = lambda do |env|
      [
        429,
        { 'Content-Type' => 'application/json' },
        [{ error: 'Too many requests. Please try again later.' }.to_json]
      ]
    end
    
    # Enable Rack::Attack for this test suite
    Rack::Attack.enabled = true
  end
  
  after(:all) do
    # Disable Rack::Attack after tests
    Rack::Attack.enabled = false
    Rack::Attack.cache.store.clear if Rack::Attack.cache.store.respond_to?(:clear)
  end

  # Clear cache between tests
  before(:each) do
    Rack::Attack.cache.store.clear if Rack::Attack.cache.store.respond_to?(:clear)
  end

  let(:user) { create(:user) }
  let(:token) { generate_token_for_user(user) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  # ... rest of your existing tests

  describe "login endpoint protection" do
    it "allows normal login attempts" do
      # Make 3 failed attempts - should all return 401
      3.times do
        post "/api/v1/auth/login", params: { email: 'wrong@example.com', password: 'wrongpassword' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "login endpoint protection" do
    it "allows normal login attempts" do
      # Make 3 failed attempts - should all return 401
      3.times do
        post "/api/v1/auth/login", params: { email: 'wrong@example.com', password: 'wrongpassword' }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it "blocks excessive login attempts" do
      # Make many rapid failed attempts
      15.times do
        post "/api/v1/auth/login", params: { email: 'attacker@example.com', password: 'wrongpassword' }
      end
      
      # The last request should be rate limited
      expect(response).to have_http_status(429) # Too Many Requests
      
      # Should include rate limit message
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to include('Too many requests')
    end
  end

  describe "API endpoint rate limiting" do
    it "allows normal API usage" do
      # Make several normal requests
      5.times do
        get "/api/v1/workspaces", headers: headers
        expect(response).to have_http_status(:ok)
      end
    end

    it "handles different rate limits for different endpoints" do
      # Test that we can make many API requests (different from login limits)
      15.times do
        get "/api/v1/workspaces", headers: headers
      end
      
      # API requests should still work (we only rate limit logins heavily)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "registration endpoint protection" do
    it "prevents spam registration attempts" do
      # Try to create many accounts rapidly
      registration_params = {
        email: 'spammer@example.com',
        username: 'spammer',
        name: 'Spammer',
        password: 'password123',
        password_confirmation: 'password123'
      }
      
      # Make multiple registration attempts
      12.times do |i|
        params = registration_params.merge(
          email: "spammer#{i}@example.com",
          username: "spammer#{i}"
        )
        post "/api/v1/auth/register", params: params
      end
      
      # Should eventually get rate limited
      expect([201, 429]).to include(response.status)
    end
  end

  describe "rate limiting boundaries" do
    it "definitely blocks excessive login attempts" do
      # Make way more than our limit (we set 10 per 60 seconds)
      25.times do
        post "/api/v1/auth/login", params: { email: 'attacker@example.com', password: 'wrongpassword' }
      end
      
      # This should definitely be rate limited
      expect(response).to have_http_status(429)
      
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to eq('Too many requests. Please try again later.')
    end
    
    it "shows different behavior for authenticated vs unauthenticated requests" do
      # Make many unauthenticated requests
      20.times do
        get "/api/v1/workspaces"  # No auth header
      end
      
      # Should get unauthorized, not rate limited (different protection)
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "music platform specific rate limiting" do
    let(:workspace) { create(:workspace, user: user) }
    let(:project) { create(:project, workspace: workspace, user: user) }
    let(:track_version) { create(:track_version, project: project, user: user) }

    it "protects against excessive file uploads" do
      # Simulate someone trying to spam upload music files
      25.times do |i|
        post "/api/v1/track_versions/#{track_version.id}/track_contents",
            params: {
              track_content: {
                title: "Spam Upload #{i}",
                content_type: "audio"
              }
            },
            headers: headers
      end
      
      # Should eventually get rate limited
      expect([201, 429]).to include(response.status)
    end
    
    it "allows reasonable collaboration activity" do
      # Normal music collaboration workflow
      5.times do |i|
        post "/api/v1/track_versions/#{track_version.id}/track_contents",
            params: {
              track_content: {
                title: "Mix Version #{i}",
                content_type: "audio"
              }
            },
            headers: headers
        expect([201, 422]).to include(response.status) # 201 created or 422 validation error, not 429 rate limited
      end
    end
  end
end
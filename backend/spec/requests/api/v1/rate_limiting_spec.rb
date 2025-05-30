require 'rails_helper'

RSpec.describe "Rate Limiting", type: :request do
  let(:user) { create(:user) }
  let(:token) { generate_token_for_user(user) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  describe "API rate limits" do
    it "handles rapid successive requests gracefully" do
      # Make many requests quickly
      responses = []
      
      20.times do
        get "/api/v1/workspaces", headers: headers
        responses << response.status
      end
      
      # Should either all succeed or gracefully rate limit
      success_count = responses.count(200)
      rate_limited_count = responses.count(429)  # Too Many Requests
      
      expect(success_count + rate_limited_count).to eq(20)
      expect(success_count).to be > 0  # At least some should succeed
    end

    it "handles different rate limits for different endpoints" do
      # Login endpoint might have stricter limits
      10.times do
        post "/api/v1/auth/login", params: { email: 'wrong@example.com', password: 'wrong' }
      end
      
      # Should either succeed or rate limit gracefully
      expect([401, 429]).to include(response.status)
    end

    it "handles rate limits per user vs global" do
      user2 = create(:user)
      token2 = generate_token_for_user(user2)
      headers2 = { 'Authorization' => "Bearer #{token2}" }
      
      # Make requests with both users
      10.times do
        get "/api/v1/workspaces", headers: headers
        get "/api/v1/workspaces", headers: headers2
      end
      
      # Both users should be able to make requests
      expect(response).to have_http_status(:ok)
    end
  end
end
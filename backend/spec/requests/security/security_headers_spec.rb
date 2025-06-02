# spec/requests/security/security_headers_spec.rb
require 'rails_helper'

RSpec.describe "Security Headers", type: :request do
  let(:user) { create(:user) }
  let(:token) { generate_token_for_user(user) }
  let(:auth_headers) { { 'Authorization' => "Bearer #{token}" } }

  shared_examples "essential security headers" do |endpoint, method = :get, params = nil|
    it "includes X-Frame-Options to prevent clickjacking" do
      send(method, endpoint, params: params, headers: auth_headers)
      expect(response.headers['X-Frame-Options']).to eq('DENY')
    end

    it "includes X-Content-Type-Options to prevent MIME sniffing" do
      send(method, endpoint, params: params, headers: auth_headers)
      expect(response.headers['X-Content-Type-Options']).to eq('nosniff')
    end

    it "includes X-XSS-Protection header" do
      send(method, endpoint, params: params, headers: auth_headers)
      expect(response.headers['X-XSS-Protection']).to eq('1; mode=block')
    end

    it "includes Referrer-Policy to control referrer information" do
      send(method, endpoint, params: params, headers: auth_headers)
      expect(response.headers['Referrer-Policy']).to eq('strict-origin-when-cross-origin')
    end

    it "includes Content-Security-Policy for API responses" do
      send(method, endpoint, params: params, headers: auth_headers)
      csp = response.headers['Content-Security-Policy']
      expect(csp).to include("default-src 'none'")
      expect(csp).to include("frame-ancestors 'none'")
    end
  end

  describe "API endpoints security" do
    it_behaves_like "essential security headers", "/api/v1/auth/current"
    it_behaves_like "essential security headers", "/api/v1/workspaces"
    it_behaves_like "essential security headers", "/api/v1/users"

    context "POST requests" do
      it "includes security headers for workspace creation" do
        workspace_params = { workspace: { name: "Test Workspace" } }
        post "/api/v1/workspaces", params: workspace_params, headers: auth_headers
        
        expect(response.headers['X-Frame-Options']).to eq('DENY')
        expect(response.headers['X-Content-Type-Options']).to eq('nosniff')
        expect(response.headers['X-XSS-Protection']).to eq('1; mode=block')
        expect(response.headers['Referrer-Policy']).to eq('strict-origin-when-cross-origin')
      end
    end
  end

  describe "unauthenticated endpoints" do
    it "includes security headers even for auth failures" do
      get "/api/v1/auth/current"  # No auth header
      
      expect(response).to have_http_status(:unauthorized)
      expect(response.headers['X-Frame-Options']).to eq('DENY')
      expect(response.headers['X-Content-Type-Options']).to eq('nosniff')
    end

    it "includes security headers for login endpoint" do
      post "/api/v1/auth/login", params: { email: 'wrong@example.com', password: 'wrong' }
      
      expect(response.headers['X-Frame-Options']).to be_present
      expect(response.headers['X-Content-Type-Options']).to be_present
    end
  end

  describe "error responses" do
    it "includes headers for 404 responses" do
      get "/api/v1/nonexistent", headers: auth_headers
      
      expect(response).to have_http_status(:not_found)
      expect(response.headers['X-Frame-Options']).to eq('DENY')
    end
  end

  describe "file upload security" do
    let(:workspace) { create(:workspace, user: user) }
    let(:project) { create(:project, workspace: workspace, user: user) }
    let(:track_version) { create(:track_version, project: project, user: user) }

    it "includes security headers for file uploads" do
      file = Tempfile.new(['test', '.wav'])
      file.write('test audio data')
      file.rewind

      post "/api/v1/track_versions/#{track_version.id}/track_contents",
           params: {
             track_content: { title: "Test Upload", content_type: "audio" },
             file: Rack::Test::UploadedFile.new(file.path, 'audio/wav', true)
           },
           headers: auth_headers

      expect(response.headers['X-Content-Type-Options']).to eq('nosniff')
      expect(response.headers['X-Frame-Options']).to eq('DENY')

      file.close
      file.unlink
    end
  end

  # Note: CORS preflight requests (OPTIONS) are handled by infrastructure in production
  # and don't typically carry security headers due to CORS middleware limitations
end
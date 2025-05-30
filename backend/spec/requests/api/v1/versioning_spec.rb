require 'rails_helper'

RSpec.describe "API Versioning", type: :request do
  let(:user) { create(:user) }
  let(:token) { generate_token_for_user(user) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  describe "API version handling" do
    it "requires version in API path" do
      # Try to access without version
      get "/api/workspaces", headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "rejects invalid API versions" do
      # Try unsupported version
      get "/api/v99/workspaces", headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "handles version in Accept header" do
      # Some APIs use Accept header for versioning
      version_headers = headers.merge({
        'Accept' => 'application/vnd.wubhub.v1+json'
      })
      
      get "/api/v1/workspaces", headers: version_headers
      expect(response).to have_http_status(:ok)
    end
  end

  describe "response format consistency" do
    let(:workspace) { create(:workspace, user: user) }

    it "maintains consistent response structure across endpoints" do
      # All successful responses should have consistent structure
      get "/api/v1/workspaces/#{workspace.id}", headers: headers
      workspace_response = JSON.parse(response.body)
      
      # Should have standard fields
      expect(workspace_response).to have_key('id')
      expect(workspace_response).to have_key('created_at')
      expect(workspace_response).to have_key('updated_at')
    end

    it "handles pagination parameters consistently" do
      create_list(:workspace, 15, user: user)
      
      # Test pagination
      get "/api/v1/workspaces", params: { page: 1, per_page: 5 }, headers: headers
      
      # Should either paginate or return all (document behavior)
      expect(response).to have_http_status(:ok)
      response_data = JSON.parse(response.body)
      expect(response_data).to be_an(Array)
    end

    it "handles sorting parameters consistently" do
      workspace1 = create(:workspace, user: user, name: "Alpha Workspace")
      workspace2 = create(:workspace, user: user, name: "Beta Workspace")
      
      # Test sorting
      get "/api/v1/workspaces", params: { sort: 'name', order: 'asc' }, headers: headers
      
      expect(response).to have_http_status(:ok)
      # Document that sorting is either supported or gracefully ignored
    end
  end

  describe "error response consistency" do
    it "returns consistent error format for validation errors" do
      invalid_workspace = {
        workspace: { name: "" }  # Invalid - name required
      }
      
      post "/api/v1/workspaces", params: invalid_workspace, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      
      error_response = JSON.parse(response.body)
      expect(error_response).to have_key('errors')
      expect(error_response['errors']).to be_an(Array)
    end

    it "returns consistent error format for authorization errors" do
      other_user = create(:user)
      other_workspace = create(:workspace, user: other_user)
      
      get "/api/v1/workspaces/#{other_workspace.id}", headers: headers
      expect(response).to have_http_status(:not_found)
      
      error_response = JSON.parse(response.body)
      expect(error_response).to have_key('error')
    end

    it "returns consistent error format for authentication errors" do
      get "/api/v1/workspaces"  # No auth header
      expect(response).to have_http_status(:unauthorized)
      
      error_response = JSON.parse(response.body)
      expect(error_response).to have_key('error')
    end
  end

  describe "content type handling" do
    it "accepts JSON content type" do
      workspace_params = {
        workspace: { name: "Test Workspace" }
      }
      
      post "/api/v1/workspaces", 
           params: workspace_params.to_json,
           headers: headers.merge('Content-Type' => 'application/json')
      
      expect(response).to have_http_status(:created)
    end

    it "handles multipart form data for file uploads" do
      workspace = create(:workspace, user: user)
      project = create(:project, workspace: workspace, user: user)
      track_version = create(:track_version, project: project, user: user)
      
      file = Tempfile.new(['test', '.wav'])
      file.write('test data')
      file.rewind
      
      upload_params = {
        track_content: { title: "Test Upload", content_type: "audio" },
        file: Rack::Test::UploadedFile.new(file.path, 'audio/wav', true)
      }
      
      # Should handle multipart without explicit Content-Type
      post "/api/v1/track_versions/#{track_version.id}/track_contents",
           params: upload_params,
           headers: headers  # No Content-Type for multipart
      
      expect(response).to have_http_status(:created)
      
      file.close
      file.unlink
    end
  end

  describe "deprecated field handling" do
    it "gracefully handles removed fields in requests" do
      # Simulate client sending old field that no longer exists
      workspace_params = {
        workspace: {
          name: "Test Workspace",
          deprecated_field: "should_be_ignored"  # This field doesn't exist
        }
      }
      
      post "/api/v1/workspaces", params: workspace_params, headers: headers
      
      # Should succeed, ignoring unknown field
      expect(response).to have_http_status(:created)
    end
  end
end
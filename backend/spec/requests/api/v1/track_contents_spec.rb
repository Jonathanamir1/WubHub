require 'rails_helper'

RSpec.describe "Api::V1::TrackContents", type: :request do
  let(:user) { create(:user) }
  let(:token) { generate_token_for_user(user) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  describe "GET /api/v1/containers/:container_id/track_contents" do
    it "returns track contents for a container" do
      workspace = create(:workspace, user: user)
      container = create(:container, workspace: workspace)
      track_content = create(:track_content, container: container, user: user)
      
      get "/api/v1/containers/#{container.id}/track_contents", headers: headers
      
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response).to be_an(Array)
      expect(json_response.first['id']).to eq(track_content.id)
    end
  end

  describe "POST /api/v1/containers/:container_id/track_contents" do
    it "creates a new track content in the container" do
      workspace = create(:workspace, user: user)
      container = create(:container, workspace: workspace)
      
      track_content_params = {
        track_content: {
          title: "My New Beat",
          content_type: "audio",
          description: "A fresh beat I made"
        }
      }
      
      expect {
        post "/api/v1/containers/#{container.id}/track_contents", 
            params: track_content_params, 
            headers: headers
      }.to change(TrackContent, :count).by(1)
      
      expect(response).to have_http_status(:created)
      json_response = JSON.parse(response.body)
      expect(json_response['title']).to eq("My New Beat")
      expect(json_response['container_id']).to eq(container.id)
      expect(json_response['user_id']).to eq(user.id)
    end

      it "returns errors when track content creation fails" do
        workspace = create(:workspace, user: user)
        container = create(:container, workspace: workspace)
        
        invalid_params = {
          track_content: {
            title: "",  # Invalid - title is required
            content_type: "audio"
          }
        }
        
        expect {
          post "/api/v1/containers/#{container.id}/track_contents", 
              params: invalid_params, 
              headers: headers
        }.not_to change(TrackContent, :count)
        
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include("Title can't be blank")
      end
  end

  describe "authorization" do
    it "prevents access to track contents in other users' containers" do
      other_user = create(:user)
      other_workspace = create(:workspace, user: other_user)
      other_container = create(:container, workspace: other_workspace)
      create(:track_content, container: other_container, user: other_user)
      
      get "/api/v1/containers/#{other_container.id}/track_contents", headers: headers
      
      expect(response).to have_http_status(:not_found)
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to eq('Container not found')
    end
    
    it "prevents creating track contents in other users' containers" do
      other_user = create(:user)
      other_workspace = create(:workspace, user: other_user)
      other_container = create(:container, workspace: other_workspace)
      
      track_content_params = {
        track_content: {
          title: "Unauthorized Content",
          content_type: "audio"
        }
      }
      
      post "/api/v1/containers/#{other_container.id}/track_contents", 
          params: track_content_params, 
          headers: headers
      
      expect(response).to have_http_status(:not_found)
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to eq('Container not found')
    end
  end
end
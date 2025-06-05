require 'rails_helper'

RSpec.describe "File Upload Security", type: :request do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user: user) }
  let(:project) { create(:project, workspace: workspace, user: user) }
  let(:track_version) { create(:track_version, project: project, user: user) }
  let(:token) { generate_token_for_user(user) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  describe "legitimate file uploads" do
    it "allows music file uploads" do
      # Create fake MP3 file
      file = Tempfile.new(['test_song', '.mp3'])
      file.write('fake mp3 audio data')
      file.rewind
      
      # Upload it using standard Rails file upload
      post "/api/v1/track_versions/#{track_version.id}/track_contents",
          params: {
            track_content: {
              title: "Test Song",
              content_type: "audio"
            },
            file: Rack::Test::UploadedFile.new(file.path, 'audio/mp3', true)
          },
          headers: headers
      
      # What status code should we expect for successful upload?
      expect(response).to have_http_status(:created)
      
      file.close
      file.unlink
    end
  end

  describe "malicious file protection" do
    it "blocks executable files" do
      # Create a fake executable file
      file = Tempfile.new(['malicious', '.exe'])
      file.write('fake executable content')
      file.rewind
      
      post "/api/v1/track_versions/#{track_version.id}/track_contents",
          params: {
            track_content: {
              title: "Malicious File",
              content_type: "audio"
            },
            file: Rack::Test::UploadedFile.new(file.path, 'application/octet-stream', true)
          },
          headers: headers
      
      # Should reject the upload
      expect(response).to have_http_status(:unprocessable_entity)
      
      json_response = JSON.parse(response.body)
      expect(json_response['errors']).to include(match(/file type not allowed/i))
      
      file.close
      file.unlink
    end
  end

  describe "file size protection" do
    it "blocks oversized files" do
      # Create a large fake file (100MB)
      file = Tempfile.new(['huge_file', '.mp3'])
      file.write('x' * (100 * 1024 * 1024))  # 100MB
      file.rewind
      
      post "/api/v1/track_versions/#{track_version.id}/track_contents",
          params: {
            track_content: {
              title: "Huge File",
              content_type: "audio"
            },
            file: Rack::Test::UploadedFile.new(file.path, 'audio/mp3', true)
          },
          headers: headers
      
      # Should reject due to size
      expect(response).to have_http_status(:unprocessable_entity)
      
      file.close
      file.unlink
    end
  end
end
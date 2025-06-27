# spec/requests/api/v1/chunks_debug_spec.rb
require 'rails_helper'

RSpec.describe "Debug Chunks Controller", type: :request do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user: user) }
  let(:upload_session) { create(:upload_session, user: user, workspace: workspace, status: 'pending') }
  let(:token) { generate_token_for_user(user) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }
  
  it "debugs basic chunk upload without signed URL" do
    chunk_file = create_test_file("test content")
    
    begin
      post "/api/v1/uploads/#{upload_session.id}/chunks/1",
           params: { file: chunk_file },
           headers: headers
            
      if response.status == 500
        # Check Rails logs for the actual error
      end
      
    rescue => e
    end
  end
  
  it "checks if required services exist" do
    # Check if MaliciousFileDetectionService exists
    begin
      service = MaliciousFileDetectionService.new
    rescue NameError => e
    rescue => e
    end
    
    # Check if ChunkStorageService exists
    begin
      service = ChunkStorageService.new
    rescue NameError => e
    rescue => e
    end
    
    # Check if UploadRateLimiter exists
    begin
      UploadRateLimiter.check_rate_limit!(
        user: user,
        action: :upload_chunk,
        ip_address: '127.0.0.1',
        upload_session: upload_session,
        chunk_size: 100
      )
    rescue NameError => e
    rescue => e
    end
  end
  
  private
  
  def create_test_file(content)
    file = Tempfile.new('test_chunk')
    file.write(content)
    file.rewind
    
    ActionDispatch::Http::UploadedFile.new(
      tempfile: file,
      filename: 'test_chunk.dat',
      type: 'application/octet-stream'
    )
  end
end
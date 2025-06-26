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
      
      puts "Response status: #{response.status}"
      puts "Response body: #{response.body}"
      
      if response.status == 500
        # Check Rails logs for the actual error
        puts "Internal server error occurred"
      end
      
    rescue => e
      puts "Exception during request: #{e.class}: #{e.message}"
      puts e.backtrace.first(10).join("\n")
    end
  end
  
  it "checks if required services exist" do
    # Check if MaliciousFileDetectionService exists
    begin
      service = MaliciousFileDetectionService.new
      puts "✅ MaliciousFileDetectionService is available"
    rescue NameError => e
      puts "❌ MaliciousFileDetectionService not found: #{e.message}"
    rescue => e
      puts "❌ MaliciousFileDetectionService error: #{e.message}"
    end
    
    # Check if ChunkStorageService exists
    begin
      service = ChunkStorageService.new
      puts "✅ ChunkStorageService is available"
    rescue NameError => e
      puts "❌ ChunkStorageService not found: #{e.message}"
    rescue => e
      puts "❌ ChunkStorageService error: #{e.message}"
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
      puts "✅ UploadRateLimiter is available"
    rescue NameError => e
      puts "❌ UploadRateLimiter not found: #{e.message}"
    rescue => e
      puts "✅ UploadRateLimiter available but raised: #{e.class}: #{e.message}"
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
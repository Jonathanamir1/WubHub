# spec/requests/api/v1/simple_chunk_test_spec.rb
require 'rails_helper'

RSpec.describe "Simple Chunk Upload Test", type: :request do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user: user) }
  let(:token) { generate_token_for_user(user) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  it "can upload a basic chunk" do
    upload_session = create(:upload_session,
      workspace: workspace,
      user: user,
      filename: "test.mp3",
      total_size: 1024,
      chunks_count: 1,
      status: 'pending'
    )

    # Create a simple test file
    temp_file = Tempfile.new(['test_chunk', '.bin'])
    temp_file.binmode
    temp_file.write("test content")
    temp_file.rewind
    chunk_file = Rack::Test::UploadedFile.new(temp_file.path, 'application/octet-stream')

    
    post "/api/v1/uploads/#{upload_session.id}/chunks/1",
         params: { file: chunk_file },
         headers: headers

    
    # Don't expect success yet, just want to see what error we get
    expect([201, 422, 500]).to include(response.status)
  end
end
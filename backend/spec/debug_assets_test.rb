# First, let's create a simple test to debug the issue step by step
# Save this as spec/debug_assets_test.rb and run it to see what's happening

require 'rails_helper'

RSpec.describe "Debug Assets Issue", type: :request do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user: user, template_type: 'producer') }
  let(:token) { generate_token_for_user(user) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  describe "Debug file upload" do
    it "shows exactly what happens during file upload" do
      
      # Create a simple test file
      test_file = Tempfile.new(['debug_test', '.wav'])
      test_file.write('RIFF FAKE WAV FILE DATA')
      test_file.rewind
      
      file = Rack::Test::UploadedFile.new(test_file.path, 'audio/wav')
      
      asset_params = {
        asset: { filename: "debug_test.wav" },
        file: file
      }
      
      
      post "/api/v1/workspaces/#{workspace.id}/assets", 
          params: asset_params, headers: headers      
      # Check if it's JSON or HTML error
      if response.content_type&.include?('application/json')
        begin
          json_response = JSON.parse(response.body)
        rescue JSON::ParserError => e
        end
      else
      end
      
      # Let's also check the database
      assets_count = Asset.count
      
      if assets_count > 0
        last_asset = Asset.last
        if last_asset.file_blob.attached?
        end
      end
      
      test_file.close
      test_file.unlink
      
      # Let's see what the test actually expected
      
      # If we got here, something is wrong with the response format
      expect(response.status).to eq(500), "Expected to debug the 500 error, got #{response.status}"
    end
  end
end
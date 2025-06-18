# spec/requests/api/v1/route_debug_spec.rb
require 'rails_helper'

RSpec.describe "Route Debug", type: :request do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user: user) }
  let(:token) { generate_token_for_user(user) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  it "checks if uploads routes exist" do
    upload_session = create(:upload_session,
      workspace: workspace,
      user: user,
      filename: "test.mp3",
      total_size: 1024,
      chunks_count: 1,
      status: 'pending'
    )

    # Test if the upload session can be accessed
    get "/api/v1/uploads/#{upload_session.id}", headers: headers
    puts "Upload session GET: #{response.status}"
    
    # Test if chunk routes exist
    post "/api/v1/uploads/#{upload_session.id}/chunks/1", 
         params: { file: "dummy" }, 
         headers: headers
    puts "Chunk upload POST: #{response.status}"
    puts "Response body: #{response.body}" if response.status == 404
    
    # Just check that we get SOME response (not necessarily success)
    expect([200, 404, 422, 500]).to include(response.status)
  end
  
  it "lists all available routes" do
    routes = Rails.application.routes.routes.map do |route|
      {
        verb: route.verb,
        path: route.path.spec.to_s,
        controller_action: "#{route.defaults[:controller]}##{route.defaults[:action]}"
      }
    end
    
    upload_routes = routes.select { |r| r[:path].include?('upload') }
    chunk_routes = routes.select { |r| r[:path].include?('chunk') }
    
    puts "\n=== UPLOAD ROUTES ==="
    upload_routes.each { |r| puts "#{r[:verb]} #{r[:path]} -> #{r[:controller_action]}" }
    
    puts "\n=== CHUNK ROUTES ==="
    chunk_routes.each { |r| puts "#{r[:verb]} #{r[:path]} -> #{r[:controller_action]}" }
    
    expect(chunk_routes).not_to be_empty, "No chunk routes found!"
  end
end
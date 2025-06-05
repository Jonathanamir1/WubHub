require 'rails_helper'

RSpec.describe "Debug CORS", type: :request do
  it "debugs OPTIONS request" do
    options "/api/v1/workspaces", headers: {
      'Origin' => 'http://localhost:3001',
      'Access-Control-Request-Method' => 'GET',
      'Access-Control-Request-Headers' => 'Authorization'
    }
    
    puts "Status: #{response.status}"
    puts "Headers: #{response.headers.inspect}"
    puts "Body: #{response.body}"
    
    expect(response.status).to eq(200)
  end
end

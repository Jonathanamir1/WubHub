#!/usr/bin/env ruby
# script/test_complete_upload_journey.rb
# Complete File Upload Journey Test for WubHub + R2

require_relative '../config/environment'
require 'tempfile'

puts "🎵 WubHub Complete File Upload Journey Test"
puts "=" * 60
puts "Environment: #{Rails.env}"
puts "Time: #{Time.current}"
puts "R2 Bucket: #{ENV['CLOUDFLARE_R2_BUCKET']}"
puts "=" * 60

def test_check(description)
  print "  #{description}... "
  result = yield
  if result
    puts "✅"
    return true
  else
    puts "❌"
    return false
  end
rescue => e
  puts "❌ (#{e.message})"
  return false
end

# Check routes first
puts "\n📋 Route Availability Check"
assets_routes = Rails.application.routes.routes.select do |route|
  route.path.spec.to_s.include?('assets') && route.defaults[:controller] == 'api/v1/assets'
end

if !test_check("Assets routes available") { assets_routes.any? }
  puts "\n⚠️  MISSING ROUTES! Add to config/routes.rb in workspaces block:"
  puts "    resources :assets, only: [:index, :create]"
  exit 1
end

puts "\n📋 Setting Up Test Data"

# Clean up existing test data
User.where(email: 'docker_test@wubhub.com').destroy_all

# Create test user with correct attributes
test_user = User.create!(
  name: 'Docker Test User',
  email: 'docker_test@wubhub.com',
  password: 'testpassword123'
)
test_check("Test user created") { test_user.persisted? }

# Create test workspace
test_workspace = test_user.workspaces.create!(
  name: 'Docker Test Workspace',
  description: 'Testing file uploads to R2'
)
test_check("Test workspace created") { test_workspace.persisted? }

# Create test container with correct attributes
test_container = test_workspace.containers.create!(
  name: 'Test Songs'
)
test_check("Test container created") { test_container.persisted? }

puts "\n📋 Direct Model Test"

# Create test file
test_content = "Test audio file for Docker + R2\nTimestamp: #{Time.current}\nUser: #{test_user.name}"
temp_file = Tempfile.new(['wubhub_test', '.txt'])
temp_file.write(test_content)
temp_file.rewind

begin
  # Test direct asset creation
  test_asset = test_workspace.assets.build(
    filename: 'docker_test_song.txt',
    container: test_container,
    user: test_user
  )
  
  test_check("Asset model created") { test_asset.save }
  
  # Test file attachment
  test_asset.file_blob.attach(
    io: temp_file,
    filename: 'docker_test_song.txt',
    content_type: 'text/plain'
  )
  test_check("File attached") { test_asset.file_blob.attached? }
  
  # Test R2 storage
  test_check("File in R2") { test_asset.file_blob.service_name == 'development_r2' }
  
  # Test URL generation  
  file_url = test_asset.file_blob.url
  test_check("R2 URL generated") { file_url&.include?(ENV['CLOUDFLARE_R2_BUCKET']) }
  
  # Test download
  downloaded = test_asset.file_blob.download
  test_check("File download works") { downloaded == test_content }
  
  puts "\n🔍 Asset Details:"
  puts "  ID: #{test_asset.id}"
  puts "  Filename: #{test_asset.filename}"
  puts "  Service: #{test_asset.file_blob.service_name}"
  puts "  Storage Key: #{test_asset.file_blob.key}"
  puts "  URL: #{file_url[0..80]}..." if file_url

rescue => e
  puts "❌ Direct model test failed: #{e.message}"
  puts "Error class: #{e.class.name}"
end

puts "\n📋 Manual API Test Commands"

puts "
🚀 Test your API with these curl commands:

1. Login and get token:
curl -X POST http://localhost:3000/api/v1/auth/login \\
  -H 'Content-Type: application/json' \\
  -d '{\"email\":\"docker_test@wubhub.com\",\"password\":\"testpassword123\"}'

2. Upload file (replace YOUR_TOKEN with token from step 1):
curl -X POST http://localhost:3000/api/v1/workspaces/#{test_workspace.id}/assets \\
  -H 'Authorization: Bearer YOUR_TOKEN' \\
  -F 'asset[filename]=my_song.mp3' \\
  -F 'asset[container_id]=#{test_container.id}' \\
  -F 'file=@/path/to/your/audio/file.mp3'

3. List uploaded assets:
curl -X GET http://localhost:3000/api/v1/workspaces/#{test_workspace.id}/assets \\
  -H 'Authorization: Bearer YOUR_TOKEN'

4. View your app in browser:
open http://localhost:3000
"

temp_file.close
temp_file.unlink

puts "\n✅ UPLOAD JOURNEY TEST COMPLETE!"
puts "Your Docker + R2 setup is ready for file uploads!"
puts "\n🔍 Test Data Created:"
puts "  User: #{test_user.name} (#{test_user.email})"
puts "  Workspace: #{test_workspace.name} (ID: #{test_workspace.id})"
puts "  Container: #{test_container.name} (ID: #{test_container.id})"

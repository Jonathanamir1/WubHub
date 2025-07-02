# test/simple_r2_test.rb
require 'aws-sdk-s3'

puts "🧪 Simple R2 Connection Test..."

# Configure S3 client for R2
s3_client = Aws::S3::Client.new(
  access_key_id: ENV['CLOUDFLARE_R2_ACCESS_KEY_ID'],
  secret_access_key: ENV['CLOUDFLARE_R2_SECRET_ACCESS_KEY'],
  region: 'auto',
  endpoint: ENV['CLOUDFLARE_R2_ENDPOINT'],
  force_path_style: true
)

begin
  # Test 1: List buckets
  puts "📋 Testing bucket listing..."
  response = s3_client.list_buckets
  puts "✅ Buckets found: #{response.buckets.map(&:name).join(', ')}"
  
  # Test 2: Simple file upload
  puts "\n📤 Testing simple file upload..."
  test_content = "Hello R2! #{Time.current}"
  
  s3_client.put_object(
    bucket: ENV['CLOUDFLARE_R2_BUCKET'],
    key: 'test/simple_test.txt',
    body: test_content,
    content_type: 'text/plain'
  )
  
  puts "✅ File uploaded successfully!"
  
  # Test 3: Download the file
  puts "\n📥 Testing file download..."
  response = s3_client.get_object(
    bucket: ENV['CLOUDFLARE_R2_BUCKET'],
    key: 'test/simple_test.txt'
  )
  
  downloaded_content = response.body.read
  
  if downloaded_content == test_content
    puts "✅ Download successful! Content matches."
  else
    puts "❌ Download failed! Content mismatch."
  end
  
  # Test 4: Clean up
  puts "\n🗑️ Cleaning up..."
  s3_client.delete_object(
    bucket: ENV['CLOUDFLARE_R2_BUCKET'],
    key: 'test/simple_test.txt'
  )
  
  puts "🎉 Simple R2 test completed successfully!"
  
rescue => e
  puts "❌ Simple R2 test failed: #{e.message}"
  puts "Class: #{e.class}"
  puts "Backtrace: #{e.backtrace.first(3).join("\n")}"
end
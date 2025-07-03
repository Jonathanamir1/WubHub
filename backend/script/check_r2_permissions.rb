# script/check_r2_permissions.rb
#!/usr/bin/env ruby

require_relative '../config/environment'
require 'aws-sdk-s3'

puts "🔑 R2 API Token Permissions Check"
puts "=" * 50

# Create S3 client with explicit configuration for R2
s3_client = Aws::S3::Client.new(
  access_key_id: ENV['CLOUDFLARE_R2_ACCESS_KEY_ID'],
  secret_access_key: ENV['CLOUDFLARE_R2_SECRET_ACCESS_KEY'],
  region: 'auto',
  endpoint: ENV['CLOUDFLARE_R2_ENDPOINT'],
  force_path_style: true,
  # IMPORTANT: Disable checksums for R2 compatibility
  compute_checksums: false,
  # Additional R2-specific configurations
  retry_limit: 3,
  retry_mode: 'standard'
)

bucket_name = ENV['CLOUDFLARE_R2_BUCKET']

puts "Testing permissions for bucket: #{bucket_name}"
puts "Endpoint: #{ENV['CLOUDFLARE_R2_ENDPOINT']}"

# Test 1: List Buckets (requires account-level read access)
puts "\n1️⃣ Testing: List Buckets Permission"
begin
  response = s3_client.list_buckets
  bucket_names = response.buckets.map(&:name)
  puts "✅ Can list buckets: #{bucket_names.join(', ')}"
  
  if bucket_names.include?(bucket_name)
    puts "✅ Target bucket '#{bucket_name}' exists"
  else
    puts "❌ Target bucket '#{bucket_name}' not found!"
    puts "Available buckets: #{bucket_names.join(', ')}"
  end
rescue => e
  puts "❌ Cannot list buckets: #{e.message}"
  puts "This suggests your API token might not have account-level read permissions"
end

# Test 2: List Objects in Bucket (requires bucket read access)
puts "\n2️⃣ Testing: List Objects in Bucket Permission"
begin
  response = s3_client.list_objects_v2(bucket: bucket_name, max_keys: 5)
  puts "✅ Can list objects in bucket"
  puts "Object count: #{response.contents.size}"
  if response.contents.any?
    puts "Sample objects: #{response.contents.first(3).map(&:key).join(', ')}"
  end
rescue => e
  puts "❌ Cannot list objects: #{e.message}"
  puts "Error type: #{e.class.name}"
end

# Test 3: Put Object (requires bucket write access)
puts "\n3️⃣ Testing: Put Object Permission"
test_key = "test/permissions_check_#{Time.current.to_i}.txt"
test_content = "WubHub R2 permissions test - #{Time.current}"

begin
  s3_client.put_object(
    bucket: bucket_name,
    key: test_key,
    body: test_content,
    content_type: 'text/plain',
    # IMPORTANT: Don't include checksum for R2
    metadata: {
      'uploaded-by' => 'wubhub-permissions-check',
      'test-timestamp' => Time.current.to_i.to_s
    }
  )
  puts "✅ Can upload objects to bucket"
rescue => e
  puts "❌ Cannot upload objects: #{e.message}"
  puts "Error type: #{e.class.name}"
  
  if e.message.include?('Access Denied')
    puts "💡 This means your API token lacks write permissions to this bucket"
  elsif e.message.include?('checksum')
    puts "💡 This is a checksum compatibility issue with R2"
  end
end

# Test 4: Get Object (requires bucket read access)
puts "\n4️⃣ Testing: Get Object Permission"
begin
  response = s3_client.get_object(
    bucket: bucket_name,
    key: test_key
  )
  downloaded_content = response.body.read
  
  if downloaded_content == test_content
    puts "✅ Can download objects from bucket"
    puts "✅ Content integrity verified"
  else
    puts "⚠️  Can download but content mismatch"
  end
rescue => e
  puts "❌ Cannot download objects: #{e.message}"
  puts "Error type: #{e.class.name}"
end

# Test 5: Delete Object (requires bucket delete access)
puts "\n5️⃣ Testing: Delete Object Permission"
begin
  s3_client.delete_object(
    bucket: bucket_name,
    key: test_key
  )
  puts "✅ Can delete objects from bucket"
rescue => e
  puts "❌ Cannot delete objects: #{e.message}"
  puts "Error type: #{e.class.name}"
end

# Summary and recommendations
puts "\n" + "=" * 50
puts "📋 PERMISSION REQUIREMENTS FOR R2:"
puts ""
puts "Your R2 API Token needs these permissions:"
puts "✓ Object:Read - To download files"
puts "✓ Object:Write - To upload files" 
puts "✓ Object:Delete - To delete files"
puts "✓ Bucket:Read - To list bucket contents"
puts ""
puts "Optional (for bucket management):"
puts "• Bucket:Write - To create/modify bucket settings"
puts "• Account:Read - To list all buckets"

puts "\n💡 TO FIX ACCESS DENIED ERRORS:"
puts "1. Go to Cloudflare Dashboard → R2"
puts "2. Go to 'Manage R2 API Tokens'"
puts "3. Edit your API token"
puts "4. Make sure it has these permissions:"
puts "   - Object Read, Write, Delete for bucket: #{bucket_name}"
puts "   - Bucket Read for bucket: #{bucket_name}"
puts "5. Save and update your .env file if the token changed"

puts "\n🎯 Current Token Analysis:"
puts "Access Key ID: #{ENV['CLOUDFLARE_R2_ACCESS_KEY_ID']}"
puts "Bucket: #{bucket_name}"
puts "Endpoint: #{ENV['CLOUDFLARE_R2_ENDPOINT']}"
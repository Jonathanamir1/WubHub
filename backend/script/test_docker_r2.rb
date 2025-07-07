#!/usr/bin/env ruby
# script/test_docker_r2.rb
# Simple WubHub Docker + R2 Test Script

require_relative '../config/environment'
require 'tempfile'

puts "🐳 WubHub Docker + R2 Test"
puts "=" * 50
puts "Environment: #{Rails.env}"
puts "Time: #{Time.current}"
puts "=" * 50

tests_passed = 0
tests_failed = 0

def test_check(description)
  print "#{description}... "
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

# 1. Environment Check
puts "\n📋 Environment Variables"
required_vars = %w[DATABASE_URL CLOUDFLARE_R2_ACCESS_KEY_ID CLOUDFLARE_R2_SECRET_ACCESS_KEY CLOUDFLARE_R2_BUCKET CLOUDFLARE_R2_ENDPOINT]

required_vars.each do |var|
  if test_check("  #{var}") { ENV[var].present? }
    tests_passed += 1
  else
    tests_failed += 1
  end
end

puts "\n🔍 Configuration:"
puts "  Database: #{ENV['DATABASE_URL']&.split('@')&.last}"
puts "  R2 Bucket: #{ENV['CLOUDFLARE_R2_BUCKET']}"
puts "  R2 Endpoint: #{ENV['CLOUDFLARE_R2_ENDPOINT']&.split('/')&.last}"

# 2. Database Test
puts "\n📋 Database Connection"
if test_check("  PostgreSQL connection") { ActiveRecord::Base.connection.active? }
  tests_passed += 1
else
  tests_failed += 1
end

if test_check("  Database name") { ActiveRecord::Base.connection.current_database == "wubhub_development" }
  tests_passed += 1
else
  tests_failed += 1
end

# 3. Active Storage Test
puts "\n📋 Active Storage Configuration"
service = ActiveStorage::Blob.service

if test_check("  Using S3 service (R2)") { service.class.name.include?('S3') }
  tests_passed += 1
else
  tests_failed += 1
end

puts "  Service: #{service.class.name}"
if service.class.name.include?('S3')
  puts "  Bucket: #{service.bucket.name}"
end

# 4. Direct R2 Connection Test
puts "\n📋 Cloudflare R2 Direct Test"
begin
  require 'aws-sdk-s3'
  
  s3_client = Aws::S3::Client.new(
    access_key_id: ENV['CLOUDFLARE_R2_ACCESS_KEY_ID'],
    secret_access_key: ENV['CLOUDFLARE_R2_SECRET_ACCESS_KEY'],
    region: 'auto',
    endpoint: ENV['CLOUDFLARE_R2_ENDPOINT'],
    force_path_style: true,
    compute_checksums: false
  )
  
  bucket_name = ENV['CLOUDFLARE_R2_BUCKET']
  
  # Test bucket access
  if test_check("  R2 bucket access") { 
    s3_client.list_objects_v2(bucket: bucket_name, max_keys: 1)
    true
  }
    tests_passed += 1
  else
    tests_failed += 1
  end
  
  # Test upload/download
  test_key = "docker_tests/test_#{Time.current.to_i}.txt"
  test_content = "Docker R2 Test - #{Time.current}"
  
  # Upload
  s3_client.put_object(
    bucket: bucket_name,
    key: test_key,
    body: test_content,
    content_type: 'text/plain'
  )
  
  if test_check("  File upload to R2") { true }
    tests_passed += 1
  else
    tests_failed += 1
  end
  
  # Download
  response = s3_client.get_object(bucket: bucket_name, key: test_key)
  downloaded = response.body.read
  
  if test_check("  File download from R2") { downloaded == test_content }
    tests_passed += 1
  else
    tests_failed += 1
  end
  
  # Cleanup
  s3_client.delete_object(bucket: bucket_name, key: test_key)
  test_check("  Cleanup test file") { true }
  tests_passed += 1
  
rescue => e
  puts "❌ R2 connection failed: #{e.message}"
  tests_failed += 4
end

# 5. Active Storage + R2 Integration Test
puts "\n📋 Active Storage + R2 Integration"
begin
  test_content = "Active Storage R2 Test - #{Time.current}"
  temp_file = Tempfile.new(['docker_test', '.txt'])
  temp_file.write(test_content)
  temp_file.rewind
  
  # Upload via Active Storage
  blob = ActiveStorage::Blob.create_and_upload!(
    io: temp_file,
    filename: 'docker_test.txt',
    content_type: 'text/plain'
  )
  
  if test_check("  Active Storage upload") { blob.persisted? }
    tests_passed += 1
  else
    tests_failed += 1
  end
  
  # Download via Active Storage
  downloaded = blob.download
  
  if test_check("  Active Storage download") { downloaded == test_content }
    tests_passed += 1
  else
    tests_failed += 1
  end
  
  # URL generation
  url = blob.url
  if test_check("  R2 URL generation") { url&.include?(ENV['CLOUDFLARE_R2_BUCKET']) }
    tests_passed += 1
  else
    tests_failed += 1
  end
  
  puts "  Blob ID: #{blob.id}"
  puts "  Service: #{blob.service_name}"
  puts "  URL: #{url[0..60]}..." if url
  
  # Cleanup
  temp_file.close
  temp_file.unlink
  blob.purge if blob.persisted?
  
rescue => e
  puts "❌ Active Storage integration failed: #{e.message}"
  tests_failed += 3
end

# Summary
puts "\n" + "=" * 50
puts "📊 TEST SUMMARY"
puts "=" * 50
total_tests = tests_passed + tests_failed
success_rate = total_tests > 0 ? (tests_passed.to_f / total_tests * 100).round(1) : 0

puts "Total Tests: #{total_tests}"
puts "Passed: #{tests_passed} ✅"
puts "Failed: #{tests_failed} #{'❌' if tests_failed > 0}"
puts "Success Rate: #{success_rate}%"

if tests_failed == 0
  puts "\n🎉 ALL TESTS PASSED!"
  puts "Your Docker + R2 setup is working perfectly!"
  puts "\n🚀 Ready for development:"
  puts "  • Rails: http://localhost:3000"
  puts "  • Database: PostgreSQL in Docker"
  puts "  • Storage: Cloudflare R2"
  puts "  • Live reloading: Enabled"
else
  puts "\n⚠️  #{tests_failed} test(s) failed."
  puts "Check the errors above and verify your configuration."
end

puts "\n" + "=" * 50

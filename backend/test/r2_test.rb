# test/r2_test.rb
require_relative '../config/environment'

puts "🧪 Testing Cloudflare R2 Connection for WubHub..."
puts "=" * 50

begin
  # Test environment variables
  required_vars = %w[
    CLOUDFLARE_R2_ACCESS_KEY_ID
    CLOUDFLARE_R2_SECRET_ACCESS_KEY
    CLOUDFLARE_R2_BUCKET
    CLOUDFLARE_R2_ENDPOINT
  ]
  
  puts "🔍 Checking environment variables..."
  missing_vars = required_vars.select { |var| ENV[var].blank? }
  
  if missing_vars.any?
    puts "❌ Missing environment variables: #{missing_vars.join(', ')}"
    exit 1
  end
  
  puts "✅ All environment variables present:"
  puts "   Bucket: #{ENV['CLOUDFLARE_R2_BUCKET']}"
  puts "   Endpoint: #{ENV['CLOUDFLARE_R2_ENDPOINT']}"
  puts "   Access Key ID: #{ENV['CLOUDFLARE_R2_ACCESS_KEY_ID'][0..10]}..."
  
  # Test Active Storage configuration
  puts "\n🔧 Testing Active Storage configuration..."
  service = ActiveStorage::Blob.service
  puts "   Service class: #{service.class.name}"
  
  if service.class.name.include?('S3')
    puts "✅ Active Storage is configured for S3 (R2)"
  else
    puts "⚠️  Active Storage is using: #{service.class.name}"
    puts "   You may need to update your environment config to use :development_r2"
  end
  
  # Test file upload
  puts "\n📤 Testing file upload to R2..."
  
  test_content = "Hello from WubHub! 🎵\nThis is a test upload to Cloudflare R2\nTimestamp: #{Time.current}\nBucket: #{ENV['CLOUDFLARE_R2_BUCKET']}"
  
  # Create a test file
  temp_file = Tempfile.new(['wubhub_r2_test', '.txt'])
  temp_file.write(test_content)
  temp_file.rewind
  
  # Upload using Active Storage
  blob = ActiveStorage::Blob.create_and_upload!(
    io: temp_file,
    filename: 'wubhub_r2_connection_test.txt',
    content_type: 'text/plain'
  )
  
  puts "✅ File uploaded successfully!"
  puts "   Blob ID: #{blob.id}"
  puts "   Filename: #{blob.filename}"
  puts "   Size: #{blob.byte_size} bytes"
  puts "   Service: #{blob.service_name}"
  puts "   Key: #{blob.key}"
  
  # Generate URL
  file_url = blob.url
  puts "   URL: #{file_url[0..80]}..." if file_url.length > 80
  
  # Test download
  puts "\n📥 Testing file download from R2..."
  downloaded_content = blob.download
  
  if downloaded_content == test_content
    puts "✅ Download test passed! Content matches perfectly."
  else
    puts "❌ Download test failed! Content doesn't match."
    puts "Expected length: #{test_content.length}"
    puts "Downloaded length: #{downloaded_content.length}"
  end
  
  # Test URL accessibility
  puts "\n🌐 Testing public URL accessibility..."
  require 'net/http'
  
  begin
    uri = URI(file_url)
    response = Net::HTTP.get_response(uri)
    
    if response.code == '200'
      puts "✅ Public URL is accessible (HTTP #{response.code})"
    else
      puts "⚠️  Public URL returned HTTP #{response.code}"
    end
  rescue => e
    puts "⚠️  Could not test public URL: #{e.message}"
  end
  
  # Cleanup
  puts "\n🗑️ Cleaning up test file..."
  blob.purge
  temp_file.close
  temp_file.unlink
  
  puts "\n🎉 R2 connection test completed successfully!"
  puts "   Your WubHub queue system is ready to use Cloudflare R2!"
  puts "=" * 50
  
rescue => e
  puts "\n❌ R2 connection test failed!"
  puts "Error: #{e.message}"
  puts "Class: #{e.class}"
  
  if e.backtrace
    puts "\nBacktrace:"
    puts e.backtrace.first(5).map { |line| "  #{line}" }.join("\n")
  end
  
  puts "\n🔧 Troubleshooting tips:"
  puts "1. Double-check your environment variables in .env"
  puts "2. Make sure you've updated config/storage.yml"
  puts "3. Restart your Rails server after changing config"
  puts "4. Verify your R2 bucket exists and credentials are correct"
  
  exit 1
end
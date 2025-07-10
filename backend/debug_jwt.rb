puts "🔍 JWT Secret Debug"
puts "==================="

begin
  secret = Rails.application.credentials.jwt_secret
  puts "✅ Rails.application.credentials.jwt_secret: #{secret ? 'SET' : 'NOT SET'}"
rescue => e
  puts "❌ Error accessing credentials.jwt_secret: #{e.message}"
end

begin
  env_secret = ENV['JWT_SECRET']
  puts "✅ ENV['JWT_SECRET']: #{env_secret ? 'SET' : 'NOT SET'}"
rescue => e
  puts "❌ Error accessing ENV['JWT_SECRET']: #{e.message}"
end

puts "\n🔍 Rails Environment: #{Rails.env}"

# Test basic JWT
begin
  require 'jwt'
  test_secret = 'test_secret_123'
  test_payload = { user_id: 1 }
  
  token = JWT.encode(test_payload, test_secret, 'HS256')
  puts "✅ JWT Encoding works: #{token[0..20]}..."
  
  decoded = JWT.decode(token, test_secret, true, { algorithm: 'HS256' })[0]
  puts "✅ JWT Decoding works: #{decoded}"
rescue => e
  puts "❌ JWT Test Error: #{e.message}"
end

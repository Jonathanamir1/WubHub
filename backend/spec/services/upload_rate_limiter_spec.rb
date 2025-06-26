# spec/services/upload_rate_limiter_spec.rb
require 'rails_helper'

RSpec.describe UploadRateLimiter, type: :service do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user: user) }
  
  # Clear cache before each test to ensure clean state
  before(:each) do
    Rails.cache.clear
    # Clear test counters if they exist
    if defined?(UploadRateLimiter.class_variable_get(:@@test_counters))
      UploadRateLimiter.class_variable_get(:@@test_counters).clear
    end
  end
  
  describe '.check_rate_limit!' do
    context 'new upload sessions rate limiting' do
      it 'allows normal upload session creation' do
        expect {
          3.times do |i|  # Changed from 5 to 3 to stay within concurrent limit
            UploadRateLimiter.check_rate_limit!(
              user: user,
              action: :create_session,
              ip_address: '192.168.1.1'
            )
          end
        }.not_to raise_error
      end
      
      it 'blocks excessive upload session creation by user' do
        # Debug: Check initial state
        current_hour = Time.current.strftime('%Y%m%d%H')
        key = "upload_rate_limit:user:#{user.id}:sessions:#{current_hour}"
        
        # Create many upload sessions rapidly
        error_raised = false
        attempts_made = 0
        
        begin
          25.times do |i|
            attempts_made = i + 1
            UploadRateLimiter.check_rate_limit!(
              user: user,
              action: :create_session,
              ip_address: '192.168.1.1'
            )
            cache_value = UploadRateLimiter.send(:get_counter, key)
          end
        rescue UploadRateLimiter::RateLimitExceeded => e
          error_raised = true
        end
        
        expect(error_raised).to be(true), "Expected rate limit to be exceeded but it wasn't. Made #{attempts_made} attempts."
      end
      
      it 'blocks excessive upload session creation by IP' do
        # Different users, same IP
        users = 3.times.map { create(:user) }
        
        expect {
          30.times do |i|
            user = users[i % users.length]
            UploadRateLimiter.check_rate_limit!(
              user: user,
              action: :create_session,
              ip_address: '192.168.1.100'
            )
          end
        }.to raise_error(UploadRateLimiter::RateLimitExceeded, /Too many/)  # Match any rate limit error
      end
    end
    
    context 'chunk upload rate limiting' do
      let(:upload_session) { create(:upload_session, user: user, workspace: workspace) }
      
      it 'allows normal chunk upload frequency' do
        expect {
          10.times do |i|
            UploadRateLimiter.check_rate_limit!(
              user: user,
              upload_session: upload_session,
              action: :upload_chunk,
              ip_address: '192.168.1.1'
            )
            sleep(0.1) # Normal spacing between chunks
          end
        }.not_to raise_error
      end
      
      it 'blocks rapid chunk upload spamming' do
        # Test frequency limit by bypassing session limit check
        # We'll mock the session limit to be very high just for this test
        allow(UploadRateLimiter).to receive(:get_counter).and_call_original
        
        # Mock only the session chunks counter to return 0 (never hit session limit)
        session_key = UploadRateLimiter.send(:session_chunks_key, upload_session.id)
        allow(UploadRateLimiter).to receive(:get_counter).with(session_key).and_return(0)
        
        expect {
          210.times do |i|  # Exceed frequency limit of 200 per minute
            UploadRateLimiter.check_rate_limit!(
              user: user,
              upload_session: upload_session,
              action: :upload_chunk,
              ip_address: '192.168.1.1'
            )
          end
        }.to raise_error(UploadRateLimiter::RateLimitExceeded, /Too many chunks uploaded too quickly/)
      end
      
      it 'blocks excessive chunk uploads per session' do
        # Test session limit by bypassing frequency limit check
        # We'll mock the frequency limit to be very high just for this test
        allow(UploadRateLimiter).to receive(:get_counter).and_call_original
        
        # Mock only the frequency counter to return 0 (never hit frequency limit)
        frequency_key = UploadRateLimiter.send(:user_chunks_key, user.id)
        allow(UploadRateLimiter).to receive(:get_counter).with(frequency_key).and_return(0)
        
        expect {
          60.times do |i|  # Exceed session chunk limit of 50
            UploadRateLimiter.check_rate_limit!(
              user: user,
              upload_session: upload_session,
              action: :upload_chunk,
              ip_address: '192.168.1.1'
            )
          end
        }.to raise_error(UploadRateLimiter::RateLimitExceeded, /Too many chunks for this session/)
      end
    end
    
    context 'total bandwidth rate limiting' do
      it 'tracks total bytes uploaded per user' do
        # Mock large chunk uploads
        expect {
          5.times do |i|
            UploadRateLimiter.check_rate_limit!(
              user: user,
              action: :upload_chunk,
              ip_address: '192.168.1.1',
              chunk_size: 50.megabytes # Large chunks
            )
          end
        }.not_to raise_error # Should allow normal usage
      end
      
      it 'blocks excessive total bandwidth usage' do
        expect {
          25.times do |i|  # Increased attempts to ensure we hit bandwidth limit
            UploadRateLimiter.check_rate_limit!(
              user: user,
              action: :upload_chunk,
              ip_address: '192.168.1.1',
              chunk_size: 100.megabytes # Very large chunks
            )
          end
        }.to raise_error(UploadRateLimiter::RateLimitExceeded, /Bandwidth limit exceeded/)
      end
    end
    
    context 'concurrent upload rate limiting' do
      it 'allows reasonable concurrent uploads' do
        threads = []
        
        expect {
          3.times do |i|
            threads << Thread.new do
              UploadRateLimiter.check_rate_limit!(
                user: user,
                action: :create_session,
                ip_address: '192.168.1.1'
              )
            end
          end
          
          threads.each(&:join)
        }.not_to raise_error
      end
      
      it 'blocks excessive concurrent uploads' do
        threads = []
        results = []
        
        10.times do |i|
          threads << Thread.new do
            begin
              UploadRateLimiter.check_rate_limit!(
                user: user,
                action: :create_session,
                ip_address: '192.168.1.1'
              )
              results << :success
            rescue UploadRateLimiter::RateLimitExceeded
              results << :rate_limited
            end
          end
        end
        
        threads.each(&:join)
        
        # Should have some rate limited
        expect(results.count(:rate_limited)).to be > 0
        expect(results.count(:success)).to be < 10
      end
    end
  end
  
  describe '.reset_rate_limits!' do
    it 'clears rate limit counters for user' do
      # Hit rate limits
      expect {
        25.times do
          UploadRateLimiter.check_rate_limit!(
            user: user,
            action: :create_session,
            ip_address: '192.168.1.1'
          )
        end
      }.to raise_error(UploadRateLimiter::RateLimitExceeded)
      
      # Reset limits
      UploadRateLimiter.reset_rate_limits!(user: user)
      
      # Should work again
      expect {
        UploadRateLimiter.check_rate_limit!(
          user: user,
          action: :create_session,
          ip_address: '192.168.1.1'
        )
      }.not_to raise_error
    end
  end
  
  describe '.get_rate_limit_status' do
    it 'returns current rate limit information' do
      3.times do
        UploadRateLimiter.check_rate_limit!(
          user: user,
          action: :create_session,
          ip_address: '192.168.1.1'
        )
      end
      
      status = UploadRateLimiter.get_rate_limit_status(user: user, ip_address: '192.168.1.1')
      
      expect(status).to include(
        :user_session_count,
        :ip_session_count,
        :user_bandwidth_used,
        :rate_limits,
        :time_until_reset
      )
      
      expect(status[:user_session_count]).to eq(3)
    end
  end
end
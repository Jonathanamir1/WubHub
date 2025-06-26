# spec/services/signed_url_service_spec.rb
require 'rails_helper'

RSpec.describe SignedUrlService, type: :service do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user: user) }
  let(:upload_session) { create(:upload_session, user: user, workspace: workspace) }
  
  describe '.generate_chunk_upload_url' do
    it 'generates a signed URL for chunk upload' do
      chunk_number = 1
      expires_in = 1.hour
      
      signed_url = SignedUrlService.generate_chunk_upload_url(
        upload_session: upload_session,
        chunk_number: chunk_number,
        user: user,
        expires_in: expires_in
      )
      
      expect(signed_url).to be_present
      expect(signed_url).to include("/api/v1/uploads/#{upload_session.id}/chunks/#{chunk_number}")
      expect(signed_url).to include('signature=')
      expect(signed_url).to include('expires=')
      expect(signed_url).to include('user_id=')
    end
    
    it 'generates different signatures for different chunks' do
      url1 = SignedUrlService.generate_chunk_upload_url(
        upload_session: upload_session,
        chunk_number: 1,
        user: user
      )
      
      url2 = SignedUrlService.generate_chunk_upload_url(
        upload_session: upload_session,
        chunk_number: 2,
        user: user
      )
      
      expect(url1).not_to eq(url2)
      
      # Extract signatures
      sig1 = URI.decode_www_form(URI.parse(url1).query).to_h['signature']
      sig2 = URI.decode_www_form(URI.parse(url2).query).to_h['signature']
      expect(sig1).not_to eq(sig2)
    end
    
    it 'generates different signatures for different users' do
      other_user = create(:user)
      other_workspace = create(:workspace, user: other_user)
      other_session = create(:upload_session, user: other_user, workspace: other_workspace)
      
      url1 = SignedUrlService.generate_chunk_upload_url(
        upload_session: upload_session,
        chunk_number: 1,
        user: user
      )
      
      url2 = SignedUrlService.generate_chunk_upload_url(
        upload_session: other_session,
        chunk_number: 1,
        user: other_user
      )
      
      expect(url1).not_to eq(url2)
    end
    
    it 'includes expiration timestamp' do
      expires_in = 2.hours
      signed_url = SignedUrlService.generate_chunk_upload_url(
        upload_session: upload_session,
        chunk_number: 1,
        user: user,
        expires_in: expires_in
      )
      
      query_params = URI.decode_www_form(URI.parse(signed_url).query).to_h
      expires_timestamp = query_params['expires'].to_i
      
      expect(expires_timestamp).to be_within(10).of((Time.current + expires_in).to_i)
    end
    
    it 'uses default expiration when not specified' do
      signed_url = SignedUrlService.generate_chunk_upload_url(
        upload_session: upload_session,
        chunk_number: 1,
        user: user
      )
      
      query_params = URI.decode_www_form(URI.parse(signed_url).query).to_h
      expires_timestamp = query_params['expires'].to_i
      
      # Default should be 1 hour
      expected_expiration = (Time.current + 1.hour).to_i
      expect(expires_timestamp).to be_within(10).of(expected_expiration)
    end
  end
  
  describe '.verify_chunk_upload_signature' do
    let(:valid_signed_url) do
      SignedUrlService.generate_chunk_upload_url(
        upload_session: upload_session,
        chunk_number: 1,
        user: user,
        expires_in: 1.hour
      )
    end
    
    let(:valid_params) { URI.decode_www_form(URI.parse(valid_signed_url).query).to_h }
    
    it 'verifies valid signatures successfully' do
      result = SignedUrlService.verify_chunk_upload_signature(
        upload_session_id: upload_session.id,
        chunk_number: 1,
        user_id: user.id,
        signature: valid_params['signature'],
        expires: valid_params['expires']
      )
      
      expect(result[:valid]).to be true
      expect(result[:error]).to be_nil
    end
    
    it 'rejects expired signatures' do
      # Generate URL that expires immediately
      expired_url = SignedUrlService.generate_chunk_upload_url(
        upload_session: upload_session,
        chunk_number: 1,
        user: user,
        expires_in: -1.minute  # Already expired
      )
      
      expired_params = URI.decode_www_form(URI.parse(expired_url).query).to_h
      
      result = SignedUrlService.verify_chunk_upload_signature(
        upload_session_id: upload_session.id,
        chunk_number: 1,
        user_id: user.id,
        signature: expired_params['signature'],
        expires: expired_params['expires']
      )
      
      expect(result[:valid]).to be false
      expect(result[:error]).to eq('Signature expired')
    end
    
    it 'rejects tampered signatures' do
      tampered_signature = valid_params['signature'].tr('a-f0-9', '0-9a-f')  # Scramble hex chars
      
      result = SignedUrlService.verify_chunk_upload_signature(
        upload_session_id: upload_session.id,
        chunk_number: 1,
        user_id: user.id,
        signature: tampered_signature,
        expires: valid_params['expires']
      )
      
      expect(result[:valid]).to be false
      expect(result[:error]).to eq('Invalid signature')
    end
    
    it 'rejects signatures for wrong upload session' do
      other_session = create(:upload_session, user: user, workspace: workspace)
      
      result = SignedUrlService.verify_chunk_upload_signature(
        upload_session_id: other_session.id,  # Different session
        chunk_number: 1,
        user_id: user.id,
        signature: valid_params['signature'],
        expires: valid_params['expires']
      )
      
      expect(result[:valid]).to be false
      expect(result[:error]).to eq('Invalid signature')
    end
    
    it 'rejects signatures for wrong chunk number' do
      result = SignedUrlService.verify_chunk_upload_signature(
        upload_session_id: upload_session.id,
        chunk_number: 2,  # Different chunk number
        user_id: user.id,
        signature: valid_params['signature'],
        expires: valid_params['expires']
      )
      
      expect(result[:valid]).to be false
      expect(result[:error]).to eq('Invalid signature')
    end
    
    it 'rejects signatures for wrong user' do
      other_user = create(:user)
      
      result = SignedUrlService.verify_chunk_upload_signature(
        upload_session_id: upload_session.id,
        chunk_number: 1,
        user_id: other_user.id,  # Different user
        signature: valid_params['signature'],
        expires: valid_params['expires']
      )
      
      expect(result[:valid]).to be false
      expect(result[:error]).to eq('Invalid signature')
    end
    
    it 'handles missing parameters gracefully' do
      result = SignedUrlService.verify_chunk_upload_signature(
        upload_session_id: upload_session.id,
        chunk_number: 1,
        user_id: user.id,
        signature: nil,
        expires: valid_params['expires']
      )
      
      expect(result[:valid]).to be false
      expect(result[:error]).to eq('Missing signature parameters')
    end
  end
  
  describe '.generate_batch_chunk_urls' do
    it 'generates signed URLs for multiple chunks' do
      chunk_numbers = [1, 2, 3, 4, 5]
      expires_in = 30.minutes
      
      urls = SignedUrlService.generate_batch_chunk_urls(
        upload_session: upload_session,
        chunk_numbers: chunk_numbers,
        user: user,
        expires_in: expires_in
      )
      
      expect(urls).to be_a(Hash)
      expect(urls.keys).to match_array(chunk_numbers)
      
      chunk_numbers.each do |chunk_number|
        url = urls[chunk_number]
        expect(url).to include("/api/v1/uploads/#{upload_session.id}/chunks/#{chunk_number}")
        expect(url).to include('signature=')
        expect(url).to include('expires=')
      end
    end
    
    it 'generates unique signatures for each chunk in batch' do
      urls = SignedUrlService.generate_batch_chunk_urls(
        upload_session: upload_session,
        chunk_numbers: [1, 2, 3],
        user: user
      )
      
      signatures = urls.values.map do |url|
        URI.decode_www_form(URI.parse(url).query).to_h['signature']
      end
      
      expect(signatures.uniq.length).to eq(3)  # All unique
    end
  end
  
  describe 'security considerations' do
    it 'uses HMAC-SHA256 for signature generation' do
      # This is more of a documentation test to ensure we're using strong crypto
      url = SignedUrlService.generate_chunk_upload_url(
        upload_session: upload_session,
        chunk_number: 1,
        user: user
      )
      
      query_params = URI.decode_www_form(URI.parse(url).query).to_h
      signature = query_params['signature']
      
      # HMAC-SHA256 produces 64-character hex strings
      expect(signature).to match(/\A[a-f0-9]{64}\z/)
    end
    
    it 'includes all critical parameters in signature' do
      # Ensure tampering with any critical parameter invalidates signature
      valid_url = SignedUrlService.generate_chunk_upload_url(
        upload_session: upload_session,
        chunk_number: 1,
        user: user
      )
      
      valid_params = URI.decode_www_form(URI.parse(valid_url).query).to_h
      
      # Test that changing expires invalidates signature
      result = SignedUrlService.verify_chunk_upload_signature(
        upload_session_id: upload_session.id,
        chunk_number: 1,
        user_id: user.id,
        signature: valid_params['signature'],
        expires: (valid_params['expires'].to_i + 3600).to_s  # Add 1 hour
      )
      
      expect(result[:valid]).to be false
    end
  end
end
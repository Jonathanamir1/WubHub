# app/services/signed_url_service.rb
class SignedUrlService
  # Custom exception for signature verification failures
  class SignatureError < StandardError; end
  
  # Default expiration time for signed URLs
  DEFAULT_EXPIRES_IN = 1.hour
  
  # Maximum allowed expiration time (security limit)
  MAX_EXPIRES_IN = 24.hours
  
  class << self
    # Generate a signed URL for chunk upload
    def generate_chunk_upload_url(upload_session:, chunk_number:, user:, expires_in: DEFAULT_EXPIRES_IN)
      # Validate inputs
      raise ArgumentError, "upload_session cannot be nil" if upload_session.nil?
      raise ArgumentError, "chunk_number must be positive" if chunk_number.to_i <= 0
      raise ArgumentError, "user cannot be nil" if user.nil?
      raise ArgumentError, "expires_in too long" if expires_in > MAX_EXPIRES_IN
      
      # Calculate expiration timestamp
      expires_at = Time.current + expires_in
      expires_timestamp = expires_at.to_i
      
      # Build base URL
      base_url = "/api/v1/uploads/#{upload_session.id}/chunks/#{chunk_number}"
      
      # Create signature payload
      payload = build_signature_payload(
        upload_session_id: upload_session.id,
        chunk_number: chunk_number,
        user_id: user.id,
        expires: expires_timestamp
      )
      
      # Generate HMAC-SHA256 signature
      signature = generate_hmac_signature(payload)
      
      # Build query parameters
      query_params = {
        'signature' => signature,
        'expires' => expires_timestamp.to_s,
        'user_id' => user.id.to_s
      }
      
      # Return complete signed URL
      "#{base_url}?#{query_params.to_query}"
    end
    
    # Generate signed URLs for multiple chunks (batch operation)
    def generate_batch_chunk_urls(upload_session:, chunk_numbers:, user:, expires_in: DEFAULT_EXPIRES_IN)
      raise ArgumentError, "chunk_numbers cannot be empty" if chunk_numbers.empty?
      
      urls = {}
      
      chunk_numbers.each do |chunk_number|
        urls[chunk_number] = generate_chunk_upload_url(
          upload_session: upload_session,
          chunk_number: chunk_number,
          user: user,
          expires_in: expires_in
        )
      end
      
      urls
    end
    
    # Verify a chunk upload signature
    def verify_chunk_upload_signature(upload_session_id:, chunk_number:, user_id:, signature:, expires:)
      # Check for missing parameters
      if signature.blank? || expires.blank? || user_id.blank?
        return { valid: false, error: 'Missing signature parameters' }
      end
      
      # Check expiration
      expires_timestamp = expires.to_i
      if Time.current.to_i > expires_timestamp
        return { valid: false, error: 'Signature expired' }
      end
      
      # Rebuild expected signature
      payload = build_signature_payload(
        upload_session_id: upload_session_id,
        chunk_number: chunk_number,
        user_id: user_id,
        expires: expires_timestamp
      )
      
      expected_signature = generate_hmac_signature(payload)
      
      # Constant-time comparison to prevent timing attacks
      if secure_compare(signature, expected_signature)
        { valid: true, error: nil }
      else
        { valid: false, error: 'Invalid signature' }
      end
    end
    
    # Verify signature from request parameters (convenience method)
    def verify_request_signature(upload_session_id:, chunk_number:, params:)
      verify_chunk_upload_signature(
        upload_session_id: upload_session_id,
        chunk_number: chunk_number,
        user_id: params[:user_id],
        signature: params[:signature],
        expires: params[:expires]
      )
    end
    
    # Extract signature parameters from URL
    def extract_signature_params(url)
      uri = URI.parse(url)
      query_params = URI.decode_www_form(uri.query || '').to_h
      
      {
        signature: query_params['signature'],
        expires: query_params['expires'],
        user_id: query_params['user_id']&.to_i
      }
    end
    
    # Check if a signed URL is expired (without full verification)
    def url_expired?(url)
      params = extract_signature_params(url)
      return true if params[:expires].blank?
      
      Time.current.to_i > params[:expires].to_i
    end
    
    private
    
    # Build the payload string for signature generation
    def build_signature_payload(upload_session_id:, chunk_number:, user_id:, expires:)
      # Include all critical parameters that should be tamper-proof
      [
        'chunk_upload',           # Operation type
        upload_session_id.to_s,   # Session ID
        chunk_number.to_s,        # Chunk number
        user_id.to_s,            # User ID
        expires.to_s             # Expiration timestamp
      ].join('|')
    end
    
    # Generate HMAC-SHA256 signature
    def generate_hmac_signature(payload)
      OpenSSL::HMAC.hexdigest('SHA256', signing_key, payload)
    end
    
    # Get the signing key from Rails credentials
    def signing_key
      # Use Rails secret key base if no specific signing key is configured
      Rails.application.secret_key_base
    end
    
    # Constant-time string comparison to prevent timing attacks
    def secure_compare(a, b)
      return false if a.blank? || b.blank?
      return false if a.bytesize != b.bytesize
      
      # Use ActiveSupport's secure compare if available
      if defined?(ActiveSupport::SecurityUtils)
        ActiveSupport::SecurityUtils.secure_compare(a, b)
      else
        # Fallback constant-time comparison
        result = 0
        a.bytes.zip(b.bytes) { |x, y| result |= x ^ y }
        result == 0
      end
    end
  end
  
  # Instance methods for when you need stateful operations
  def initialize(upload_session: nil, user: nil, expires_in: DEFAULT_EXPIRES_IN)
    @upload_session = upload_session
    @user = user
    @expires_in = expires_in
  end
  
  def generate_chunk_url(chunk_number)
    self.class.generate_chunk_upload_url(
      upload_session: @upload_session,
      chunk_number: chunk_number,
      user: @user,
      expires_in: @expires_in
    )
  end
  
  def generate_all_chunk_urls
    return nil unless @upload_session
    
    chunk_numbers = (1..@upload_session.chunks_count).to_a
    self.class.generate_batch_chunk_urls(
      upload_session: @upload_session,
      chunk_numbers: chunk_numbers,
      user: @user,
      expires_in: @expires_in
    )
  end
  
  private
  
  attr_reader :upload_session, :user, :expires_in
end
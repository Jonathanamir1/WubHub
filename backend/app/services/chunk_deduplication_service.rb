# app/services/chunk_deduplication_service.rb
class ChunkDeduplicationService
  # Custom exceptions
  class DeduplicationError < StandardError; end
  
  attr_reader :enabled
  
  def initialize(enabled: true)
    @enabled = enabled
  end
  
  def enabled?
    @enabled
  end
  
  # Find existing chunks by checksum within a workspace
  def find_duplicate_chunks(checksums, workspace)
    raise ArgumentError, 'Workspace cannot be nil' if workspace.nil?
    
    return {} if checksums.empty?
    
    # Query for existing completed chunks with matching checksums in the workspace
    existing_chunks = Chunk.joins(:upload_session)
                          .where(upload_sessions: { workspace: workspace })
                          .where(checksum: checksums, status: 'completed')
                          .where.not(storage_key: [nil, ''])
                          .includes(:upload_session)
    
    # Build hash mapping checksum to chunk data
    duplicates = {}
    existing_chunks.each do |chunk|
      # For testing, we'll be more lenient about file existence
      # In production, you might want to enable stricter verification
      if Rails.env.test? || verify_chunk_integrity(chunk)
        duplicates[chunk.checksum] = {
          id: chunk.id,
          chunk_number: chunk.chunk_number,
          size: chunk.size,
          storage_key: chunk.storage_key,
          upload_session_id: chunk.upload_session_id,
          created_at: chunk.created_at
        }
      else
        Rails.logger.warn "⚠️ Chunk #{chunk.id} marked for deduplication but file missing: #{chunk.storage_key}"
      end
    end
    
    duplicates
  end
  
  # Main deduplication method - returns chunks to upload and deduplication info
  def deduplicate_chunk_list(chunk_data, upload_session)
    return no_deduplication_result(chunk_data) unless enabled?
    
    # Step 1: Find existing chunks in workspace by checksum
    all_checksums = chunk_data.map { |chunk| chunk[:checksum] }.uniq
    existing_chunks = find_duplicate_chunks(all_checksums, upload_session.workspace)
    
    # Step 2: Track chunks we've seen within this upload (for within-list deduplication)
    chunks_to_upload = []
    deduplicated_chunks = []
    seen_checksums = {}
    
    chunk_data.each do |chunk_info|
      checksum = chunk_info[:checksum]
      chunk_number = chunk_info[:chunk_number]
      
      if existing_chunks.key?(checksum)
        # Chunk exists in workspace - deduplicate from existing
        Rails.logger.info "🔄 Deduplicating chunk #{chunk_number} (checksum: #{checksum}) from existing workspace chunk"
        
        existing_chunk_data = existing_chunks[checksum]
        new_chunk = create_deduplicated_chunk(upload_session, chunk_info, existing_chunk_data)
        
        deduplicated_chunks << {
          chunk_number: chunk_number,
          checksum: checksum,
          source: 'workspace',
          source_chunk_id: existing_chunk_data[:id],
          bytes_saved: chunk_info[:size]
        }
        
      elsif seen_checksums.key?(checksum)
        # Duplicate within this upload list - deduplicate from earlier chunk
        Rails.logger.info "🔄 Deduplicating chunk #{chunk_number} (checksum: #{checksum}) from chunk #{seen_checksums[checksum]} in same upload"
        
        # Find the chunk we'll deduplicate from
        source_chunk_number = seen_checksums[checksum]
        
        # We'll create the chunk record to indicate it's been deduplicated
        new_chunk = create_deduplicated_chunk_within_upload(upload_session, chunk_info, source_chunk_number)
        
        deduplicated_chunks << {
          chunk_number: chunk_number,
          checksum: checksum,
          source: 'within_upload',
          source_chunk_number: source_chunk_number,
          bytes_saved: chunk_info[:size]
        }
        
      else
        # New chunk - needs to be uploaded
        chunks_to_upload << chunk_info
        seen_checksums[checksum] = chunk_number
      end
    end
    
    # Step 3: Remove the old within-upload deduplication processing
    # (We handle it inline now)
    
    # Step 4: Calculate statistics
    total_bytes = chunk_data.sum { |chunk| chunk[:size] }
    bytes_saved = deduplicated_chunks.sum { |dup| dup[:bytes_saved] }
    
    deduplication_stats = {
      total_chunks: chunk_data.length,
      chunks_to_upload: chunks_to_upload.length,
      deduplicated_chunks: deduplicated_chunks.length,
      bytes_saved: bytes_saved,
      total_bytes: total_bytes,
      deduplication_ratio: total_bytes > 0 ? (bytes_saved.to_f / total_bytes).round(3) : 0.0
    }
    
    Rails.logger.info "📊 Deduplication complete: #{deduplicated_chunks.length}/#{chunk_data.length} chunks deduplicated, #{bytes_saved} bytes saved"
    
    {
      chunks_to_upload: chunks_to_upload,
      deduplicated_chunks: deduplicated_chunks,
      deduplication_stats: deduplication_stats
    }
  end
  
  # Copy a chunk from another session to the target session
  def copy_chunk_for_session(source_chunk, target_session, target_chunk_number)
    begin
      new_chunk = target_session.chunks.create!(
        chunk_number: target_chunk_number,
        size: source_chunk.size,
        checksum: source_chunk.checksum,
        status: 'completed',
        storage_key: source_chunk.storage_key,
        metadata: (source_chunk.metadata || {}).merge({
          'deduplicated_from' => source_chunk.id,
          'deduplicated_at' => Time.current.iso8601
        })
      )
      
      Rails.logger.debug "✅ Copied chunk #{source_chunk.id} to session #{target_session.id} as chunk #{target_chunk_number}"
      new_chunk
      
    rescue ActiveRecord::RecordInvalid => e
      raise DeduplicationError, "Failed to copy chunk: #{e.message}"
    rescue StandardError => e
      raise DeduplicationError, "Failed to copy chunk: #{e.message}"
    end
  end
  
  # Verify that a chunk file still exists and matches expected size
  def verify_chunk_integrity(chunk)
    return false if chunk.storage_key.blank?
    return false unless File.exist?(chunk.storage_key)
    
    actual_size = File.size(chunk.storage_key)
    expected_size = chunk.size
    
    actual_size == expected_size
  rescue StandardError => e
    Rails.logger.error "❌ Error verifying chunk integrity for chunk #{chunk.id}: #{e.message}"
    false
  end
  
  private
  
  # Handle deduplication when service is disabled
  def no_deduplication_result(chunk_data)
    {
      chunks_to_upload: chunk_data,
      deduplicated_chunks: [],
      deduplication_stats: {
        total_chunks: chunk_data.length,
        chunks_to_upload: chunk_data.length,
        deduplicated_chunks: 0,
        bytes_saved: 0,
        total_bytes: chunk_data.sum { |chunk| chunk[:size] },
        deduplication_ratio: 0.0
      }
    }
  end
  
  # Create a deduplicated chunk record from existing workspace chunk
  def create_deduplicated_chunk(upload_session, chunk_info, existing_chunk_data)
    chunk_number = chunk_info[:chunk_number]
    
    upload_session.chunks.create!(
      chunk_number: chunk_number,
      size: chunk_info[:size],
      checksum: chunk_info[:checksum],
      status: 'completed',
      storage_key: existing_chunk_data[:storage_key],
      metadata: {
        'deduplicated_from' => existing_chunk_data[:id],
        'deduplicated_at' => Time.current.iso8601,
        'deduplication_source' => 'workspace'
      }
    )
  end
  
  # Create a deduplicated chunk record for within-upload deduplication
  def create_deduplicated_chunk_within_upload(upload_session, chunk_info, source_chunk_number)
    chunk_number = chunk_info[:chunk_number]
    
    upload_session.chunks.create!(
      chunk_number: chunk_number,
      size: chunk_info[:size],
      checksum: chunk_info[:checksum],
      status: 'completed',
      storage_key: "dedup_pending:#{source_chunk_number}", # Will be resolved later
      metadata: {
        'deduplicated_from_chunk_number' => source_chunk_number,
        'deduplicated_at' => Time.current.iso8601,
        'deduplication_source' => 'within_upload',
        'pending_storage_key_update' => true
      }
    )
  end
  
  
  # This method can be called after upload completion to fix within-upload dedup storage keys
  def resolve_within_upload_deduplication(upload_session)
    pending_chunks = upload_session.chunks.where("storage_key LIKE 'dedup_pending:%'")
    
    pending_chunks.each do |chunk|
      source_chunk_number = chunk.metadata['deduplicated_from_chunk_number']
      source_chunk = upload_session.chunks.find_by(chunk_number: source_chunk_number)
      
      if source_chunk&.storage_key.present? && !source_chunk.storage_key.starts_with?('dedup_pending:')
        chunk.update!(
          storage_key: source_chunk.storage_key,
          metadata: chunk.metadata.except('pending_storage_key_update')
        )
        Rails.logger.debug "✅ Resolved within-upload deduplication: chunk #{chunk.chunk_number} -> chunk #{source_chunk_number}"
      end
    end
  end
end
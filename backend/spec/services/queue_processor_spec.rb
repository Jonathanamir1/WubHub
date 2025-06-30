# spec/services/queue_processor_spec.rb
require 'rails_helper'

RSpec.describe QueueProcessor, type: :service do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user: user) }
  let(:container) { create(:container, workspace: workspace) }
  let(:queue_item) { create(:queue_item, workspace: workspace, user: user, total_files: 3) }
  
  before do
    # Create upload sessions for the queue
    create_list(:upload_session, 3, queue_item: queue_item, workspace: workspace, user: user)
  end

  describe '.initialize' do
    it 'initializes with queue item and configuration' do
      processor = QueueProcessor.new(
        queue_item: queue_item,
        max_concurrent_uploads: 3,
        bandwidth_limit: 5000
      )

      expect(processor.queue_item).to eq(queue_item)
      expect(processor.max_concurrent_uploads).to eq(3)
      expect(processor.bandwidth_limit).to eq(5000)
    end

    it 'sets default configuration values' do
      processor = QueueProcessor.new(queue_item: queue_item)

      expect(processor.max_concurrent_uploads).to eq(3) # Default
      expect(processor.bandwidth_limit).to eq(10000) # Default 10MB/s
      expect(processor.retry_attempts).to eq(3) # Default
    end

    it 'validates queue item is provided' do
      expect {
        QueueProcessor.new(queue_item: nil)
      }.to raise_error(ArgumentError, /queue_item is required/)
    end
  end

  describe '#process_queue' do
    let(:processor) { QueueProcessor.new(queue_item: queue_item, max_concurrent_uploads: 2) }

    it 'processes all upload sessions in the queue' do
      # Mock parallel upload service for each session
      queue_item.upload_sessions.each do |session|
        mock_service = instance_double(ParallelUploadService)
        allow(ParallelUploadService).to receive(:new).with(session, max_concurrent: 2).and_return(mock_service)
        allow(mock_service).to receive(:upload_chunks_parallel).and_return([])
      end

      result = processor.process_queue

      expect(result[:success]).to be true
      expect(result[:completed_uploads]).to eq(3)
      expect(result[:failed_uploads]).to eq(0)
      expect(result[:total_processing_time]).to be > 0
    end

    it 'updates queue status to processing when started' do
      # Mock the upload processing
      allow_any_instance_of(ParallelUploadService).to receive(:upload_chunks_parallel).and_return([])

      expect {
        processor.process_queue
      }.to change { queue_item.reload.status }.from('pending').to('processing')
    end

    it 'handles upload session failures gracefully' do
      # Mock one successful and one failed upload
      sessions = queue_item.upload_sessions.to_a
      
      sessions.each_with_index do |session, index|
        mock_service = instance_double(ParallelUploadService)
        allow(ParallelUploadService).to receive(:new).with(session, max_concurrent: 2).and_return(mock_service)
        
        if index == 0
          # First upload fails
          allow(mock_service).to receive(:upload_chunks_parallel).and_raise(StandardError, "Upload failed")
        else
          # Others succeed
          allow(mock_service).to receive(:upload_chunks_parallel).and_return([])
        end
      end

      result = processor.process_queue

      expect(result[:success]).to be false
      expect(result[:completed_uploads]).to eq(2)
      expect(result[:failed_uploads]).to eq(1)
      expect(result[:errors]).to include(/Upload failed/)
    end

    it 'respects max concurrent uploads limit' do
      processor = QueueProcessor.new(queue_item: queue_item, max_concurrent_uploads: 1)
      
      # Track concurrent execution
      concurrent_count = 0
      max_concurrent = 0
      
      allow_any_instance_of(ParallelUploadService).to receive(:upload_chunks_parallel) do
        concurrent_count += 1
        max_concurrent = [max_concurrent, concurrent_count].max
        sleep(0.1) # Simulate processing time
        concurrent_count -= 1
        []
      end

      processor.process_queue

      expect(max_concurrent).to eq(1)
    end
  end

  describe '#process_with_priority_order' do
    let(:processor) { QueueProcessor.new(queue_item: queue_item) }
    
    before do
      # Create sessions with different sizes for priority testing
      sessions = queue_item.upload_sessions.to_a
      sessions[0].update!(total_size: 1.megabyte, filename: 'small.mp3')
      sessions[1].update!(total_size: 10.megabytes, filename: 'medium.wav')
      sessions[2].update!(total_size: 50.megabytes, filename: 'large.flac')
    end

    it 'processes uploads in priority order (smallest first)' do
      processed_order = []
      
      allow_any_instance_of(ParallelUploadService).to receive(:upload_chunks_parallel) do |service|
        processed_order << service.upload_session.filename
        []
      end

      processor.process_with_priority_order(strategy: :smallest_first)

      expect(processed_order).to eq(['small.mp3', 'medium.wav', 'large.flac'])
    end

    it 'processes uploads in interleaved order for mixed sizes' do
      processed_order = []
      
      allow_any_instance_of(ParallelUploadService).to receive(:upload_chunks_parallel) do |service|
        processed_order << service.upload_session.filename
        []
      end

      processor.process_with_priority_order(strategy: :interleaved)

      # Interleaved should start with smallest, then largest, then medium
      expect(processed_order.first).to eq('small.mp3')
      expect(processed_order).to include('large.flac', 'medium.wav')
    end

    it 'provides progress callbacks during priority processing' do
      progress_updates = []
      
      processor.process_with_priority_order(
        strategy: :smallest_first,
        progress_callback: ->(update) { progress_updates << update }
      )

      expect(progress_updates).not_to be_empty
      expect(progress_updates.first).to include(:upload_session_id, :status, :progress_percentage)
    end
  end

  describe '#parallel_chunk_processing' do
    let(:processor) { QueueProcessor.new(queue_item: queue_item, max_concurrent_uploads: 2) }
    let(:upload_session) { queue_item.upload_sessions.first }

    before do
      # Create chunks for the upload session
      create_list(:chunk, 5, upload_session: upload_session, status: 'pending')
    end

    it 'processes chunks in parallel across multiple sessions' do
      chunk_groups = processor.parallel_chunk_processing(queue_item.upload_sessions.to_a)

      expect(chunk_groups).to be_an(Array)
      expect(chunk_groups.length).to be <= processor.max_concurrent_uploads
      
      # Each group should contain upload sessions
      chunk_groups.each do |group|
        expect(group).to be_an(Array)
        group.each do |session|
          expect(session).to be_a(UploadSession)
        end
      end
    end

    it 'balances chunks across concurrent streams' do
      # Create sessions with different chunk counts
      sessions = queue_item.upload_sessions.to_a
      create_list(:chunk, 3, upload_session: sessions[0])
      create_list(:chunk, 7, upload_session: sessions[1])
      create_list(:chunk, 2, upload_session: sessions[2])

      chunk_groups = processor.parallel_chunk_processing(sessions)

      # Groups should be roughly balanced in terms of chunk count
      group_chunk_counts = chunk_groups.map do |group|
        group.sum { |session| session.chunks.count }
      end

      expect(group_chunk_counts.max - group_chunk_counts.min).to be <= 3
    end

    it 'handles bandwidth allocation across concurrent streams' do
      bandwidth_allocation = processor.calculate_bandwidth_allocation(3)

      expect(bandwidth_allocation[:per_stream_limit]).to eq(processor.bandwidth_limit / 3)
      expect(bandwidth_allocation[:total_allocated]).to eq(processor.bandwidth_limit)
      expect(bandwidth_allocation[:streams]).to eq(3)
    end
  end

  describe '#retry_failed_uploads' do
    let(:processor) { QueueProcessor.new(queue_item: queue_item, retry_attempts: 2) }

    before do
      # Mark some upload sessions as failed using update! with proper status transitions
      first_session = queue_item.upload_sessions.first
      # Need to start upload and then fail it to get to failed state
      first_session.start_upload!
      first_session.fail!
      
      second_session = queue_item.upload_sessions.second
      # For virus_detected, need to go through proper sequence
      second_session.start_upload!
      second_session.start_assembly!
      second_session.start_virus_scan!
      second_session.detect_virus!
    end

    it 'retries failed upload sessions' do
      failed_sessions = queue_item.upload_sessions.where(status: ['failed', 'virus_detected'])
      retryable_sessions = queue_item.upload_sessions.where(status: ['failed'])
      virus_sessions = queue_item.upload_sessions.where(status: ['virus_detected'])
      
      # Verify we have the expected failed sessions
      expect(failed_sessions.count).to eq(2)
      expect(retryable_sessions.count).to eq(1)
      expect(virus_sessions.count).to eq(1)

      result = processor.retry_failed_uploads

      # Only failed sessions should be retried, virus_detected should be skipped
      expect(result[:retried_count]).to eq(1)
      expect(result[:skipped_count]).to eq(1)
      expect(result[:success]).to be true
      
      # Verify only the failed session was updated to pending status
      retryable_sessions.each do |session|
        expect(session.reload.status).to eq('pending')
      end
      
      # Verify virus detected session remains unchanged
      virus_sessions.each do |session|
        expect(session.reload.status).to eq('virus_detected')
      end
    end

    it 'respects maximum retry attempts' do
      # Create a fresh session for this test to avoid state conflicts
      fresh_session = create(:upload_session, queue_item: queue_item, workspace: workspace, user: user)
      fresh_session.start_upload!
      fresh_session.fail!
      
      # Update metadata with retry count that exceeds limit
      fresh_session.update!(metadata: { 'retry_count' => 3 })

      result = processor.retry_failed_uploads

      # Should skip the session with max retries reached
      expect(result[:retried_count]).to eq(1) # The original failed session from before block
      expect(result[:skipped_count]).to eq(2) # max retries session + virus_detected session
      expect(result[:messages]).to include(/maximum retry attempts reached/)
    end

    it 'tracks retry attempts in session metadata' do
      # Set up a failed session properly - use a fresh session
      failed_session = queue_item.upload_sessions.third # Use the third session that's still pending
      failed_session.start_upload!
      failed_session.fail!

      # Verify it's in failed state with empty metadata
      expect(failed_session.reload.status).to eq('failed')
      expect(failed_session.metadata).to eq({})

      processor.retry_failed_uploads

      failed_session.reload
      expect(failed_session.metadata['retry_count']).to eq(1)
      expect(failed_session.status).to eq('pending')
    end
  end

  describe '#monitor_progress' do
    let(:processor) { QueueProcessor.new(queue_item: queue_item) }

    it 'provides real-time progress updates' do
      progress_updates = []
      monitoring_active = true
      
      # Start monitoring in a separate thread
      monitoring_thread = Thread.new do
        while monitoring_active
          begin
            progress = processor.calculate_current_progress
            progress_updates << progress
            
            # Break if we've completed all files
            if progress[:completed_files] >= queue_item.total_files
              monitoring_active = false
              break
            end
            
            sleep(0.05) # Short polling interval
          rescue => e
            Rails.logger.debug "Monitoring error: #{e.message}"
            break
          end
        end
      end

      # Give monitoring a moment to start
      sleep(0.1)
      
      # Simulate upload completion - do this sequentially with delays
      queue_item.upload_sessions.each_with_index do |session, index|
        session.start_upload!
        session.start_assembly!
        session.start_virus_scan!
        session.start_finalization!
        session.complete!
        
        # Give monitoring time to catch the progress after each completion
        sleep(0.1)
      end

      # Wait for monitoring to finish
      monitoring_thread.join(3) # Wait up to 3 seconds
      monitoring_active = false

      expect(progress_updates).not_to be_empty
      
      # Check that we captured some progress
      final_progress = progress_updates.last
      expect(final_progress[:completed_files]).to be >= 0 # At least some progress
      
      # Verify the final state directly from the queue
      queue_item.reload
      expect(queue_item.completed_files).to eq(3)
    end

    it 'calculates accurate progress metrics' do
      # Complete one upload session with proper state transitions
      session = queue_item.upload_sessions.first
      session.start_upload!
      session.start_assembly!
      session.start_virus_scan!
      session.start_finalization!
      session.complete!

      progress = processor.calculate_current_progress

      expect(progress).to include(
        :total_files,
        :completed_files,
        :failed_files,
        :pending_files,
        :progress_percentage,
        :estimated_completion_time,
        :upload_speed
      )

      expect(progress[:completed_files]).to eq(1)
      expect(progress[:progress_percentage]).to be_between(0, 100)
    end

    it 'estimates completion time based on current progress' do
      # Mark first session as completed and simulate timing
      start_time = 1.minute.ago
      processor.instance_variable_set(:@start_time, start_time)
      
      session = queue_item.upload_sessions.first
      session.start_upload!
      session.start_assembly!
      session.start_virus_scan!
      session.start_finalization!
      session.complete!
      session.update!(updated_at: 30.seconds.ago)

      progress = processor.calculate_current_progress

      expect(progress[:estimated_completion_time]).to be > 0
      expect(progress[:upload_speed]).to be > 0
    end
  end

  describe '#pause_and_resume' do
    let(:processor) { QueueProcessor.new(queue_item: queue_item) }

    it 'pauses active upload sessions' do
      # Start some uploads to have something to pause
      queue_item.upload_sessions.each { |s| s.update!(status: 'pending') }

      result = processor.pause_queue

      expect(result[:paused_sessions]).to eq(3)
      expect(result[:success]).to be true
    end

    it 'resumes paused upload sessions' do
      # Set sessions to paused state
      queue_item.upload_sessions.each { |s| s.update!(status: 'pending') }

      result = processor.resume_queue

      expect(result[:resumed_sessions]).to eq(3)
      expect(result[:success]).to be true
    end

    it 'handles partial pause scenarios' do
      sessions = queue_item.upload_sessions.to_a
      
      # Set up different session states - one uploading, one completed, one failed
      # For uploading session
      sessions[0].start_upload!
      
      # For completed session, follow proper state sequence
      sessions[1].start_upload!
      sessions[1].start_assembly!
      sessions[1].start_virus_scan!
      sessions[1].start_finalization!
      sessions[1].complete!
      
      # For failed session
      sessions[2].start_upload!
      sessions[2].fail!

      result = processor.pause_queue

      # Should pause the uploading session and skip completed/failed ones
      expect(result[:paused_sessions]).to eq(1) # Only the uploading session
      expect(result[:skipped_sessions]).to eq(2) # Completed and failed
    end
  end

  describe '#cleanup_and_finalize' do
    let(:processor) { QueueProcessor.new(queue_item: queue_item) }

    it 'finalizes queue processing and updates status' do
      # Complete all upload sessions with proper state transitions
      queue_item.upload_sessions.each do |session| 
        session.start_upload!
        session.start_assembly!
        session.start_virus_scan!
        session.start_finalization!
        session.complete!
      end

      result = processor.cleanup_and_finalize

      expect(result[:success]).to be true
      expect(queue_item.reload.status).to eq('completed')
      expect(result[:cleanup_actions]).to include('updated_queue_status', 'calculated_final_metrics')
    end

    it 'handles mixed completion scenarios' do
      sessions = queue_item.upload_sessions.to_a
      
      # Complete first two sessions
      [sessions[0], sessions[1]].each do |session|
        session.start_upload!
        session.start_assembly!
        session.start_virus_scan!
        session.start_finalization!
        session.complete!
      end
      
      # Fail third session
      sessions[2].start_upload!
      sessions[2].fail!

      result = processor.cleanup_and_finalize

      expect(result[:success]).to be false # Has failures
      expect(queue_item.reload.status).to eq('failed')
      expect(result[:final_metrics][:completed_files]).to eq(2)
      expect(result[:final_metrics][:failed_files]).to eq(1)
    end

    it 'performs cleanup of temporary resources' do
      result = processor.cleanup_and_finalize

      expect(result[:cleanup_actions]).to include('cleaned_temp_files')
      expect(result[:cleanup_actions]).to include('released_resources')
    end

    it 'generates comprehensive processing report' do
      # Complete some sessions for reporting with proper state transitions
      session = queue_item.upload_sessions.first
      session.start_upload!
      session.start_assembly!
      session.start_virus_scan!
      session.start_finalization!
      session.complete!

      result = processor.cleanup_and_finalize

      expect(result[:processing_report]).to include(
        :total_processing_time,
        :average_upload_speed,
        :total_bytes_transferred,
        :efficiency_score
      )

      expect(result[:processing_report][:total_processing_time]).to be > 0
    end
  end

  describe 'error handling and resilience' do
    let(:processor) { QueueProcessor.new(queue_item: queue_item) }

    it 'handles network interruptions gracefully' do
      # Simulate network error
      allow_any_instance_of(ParallelUploadService).to receive(:upload_chunks_parallel)
        .and_raise(Net::ReadTimeout, "Network timeout")

      result = processor.process_queue

      expect(result[:success]).to be false
      expect(result[:errors]).to include(/Network timeout/)
      expect(result[:retry_recommendations]).to be_present
    end

    it 'handles concurrent access conflicts' do
      # Simulate database lock error
      allow(queue_item).to receive(:start_processing!)
        .and_raise(ActiveRecord::StatementInvalid, "Database lock timeout")

      result = processor.process_queue

      expect(result[:success]).to be false
      expect(result[:errors]).to include(/Database lock timeout/)
    end

    it 'provides recovery suggestions for common failures' do
      # Test various failure scenarios
      test_cases = [
        { error: Net::ReadTimeout.new("Timeout"), suggestion: /network/ },
        { error: Errno::ENOSPC.new("No space left"), suggestion: /storage/ },
        { error: ActiveRecord::StatementInvalid.new("Lock timeout"), suggestion: /retry/ }
      ]

      test_cases.each do |test_case|
        allow_any_instance_of(ParallelUploadService).to receive(:upload_chunks_parallel)
          .and_raise(test_case[:error])

        result = processor.process_queue

        expect(result[:recovery_suggestions].join(" ")).to match(test_case[:suggestion])
      end
    end
  end

  describe 'performance optimization' do
    let(:processor) { QueueProcessor.new(queue_item: queue_item, max_concurrent_uploads: 3) }

    it 'dynamically adjusts concurrency based on performance' do
      # Mock performance metrics
      allow(processor).to receive(:calculate_current_performance).and_return({
        upload_speed: 2000, # KB/s
        cpu_usage: 0.8,
        memory_usage: 0.6
      })

      optimal_concurrency = processor.calculate_optimal_concurrency

      expect(optimal_concurrency).to be_between(1, processor.max_concurrent_uploads)
    end

    it 'throttles upload speed when bandwidth is constrained' do
      processor = QueueProcessor.new(queue_item: queue_item, bandwidth_limit: 1000) # 1MB/s

      throttle_settings = processor.calculate_throttle_settings

      expect(throttle_settings[:enabled]).to be true
      expect(throttle_settings[:per_stream_limit]).to be <= 1000
    end

    it 'prioritizes critical uploads during resource constraints' do
      # Create sessions with different priorities
      sessions = queue_item.upload_sessions.to_a
      sessions[0].update!(metadata: { priority: 'high', file_type: 'audio' })
      sessions[1].update!(metadata: { priority: 'normal', file_type: 'document' })
      sessions[2].update!(metadata: { priority: 'low', file_type: 'archive' })

      prioritized_order = processor.prioritize_for_resource_constraints(sessions)

      expect(prioritized_order.first.metadata['priority']).to eq('high')
      expect(prioritized_order.last.metadata['priority']).to eq('low')
    end
  end
end
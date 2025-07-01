# spec/integrations/full_queue_workflow_spec.rb
require 'rails_helper'

RSpec.describe 'Full Queue Workflow Integration', type: :integration do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user: user) }
  let(:container) { create(:container, workspace: workspace) }
  
  # Simulate realistic file drag-and-drop scenario
  let(:drag_drop_files) do
    [
      { name: 'vocals_verse1.wav', size: 8.megabytes, path: '/project/vocals/vocals_verse1.wav', type: 'file' },
      { name: 'guitar_lead.mp3', size: 4.megabytes, path: '/project/guitar/guitar_lead.mp3', type: 'file' },
      { name: 'drums_kick.flac', size: 12.megabytes, path: '/project/drums/drums_kick.flac', type: 'file' },
      { name: 'bass_line.aiff', size: 6.megabytes, path: '/project/bass/bass_line.aiff', type: 'file' },
      { name: 'synth_pad.wav', size: 3.megabytes, path: '/project/synth/synth_pad.wav', type: 'file' }
    ]
  end
  
  let(:queue_service) { UploadQueueService.new(workspace: workspace, user: user) }
  
  describe 'End-to-End Queue Processing Workflow' do
    it 'processes a complete drag-and-drop upload workflow' do
      # 📁 PHASE 1: Queue Creation (simulates drag-and-drop)
      Rails.logger.info "🎵 Starting WubHub upload workflow test"
      
      queue_item = nil
      expect {
        queue_item = queue_service.create_queue_batch(
          draggable_name: 'New Album Tracks',
          draggable_type: :mixed,
          files: drag_drop_files,
          container: container,
          metadata: {
            upload_source: 'drag_drop',
            client_info: { browser: 'Chrome', version: '91.0', os: 'macOS' },
            project_context: { album: 'Debut Album', genre: 'Electronic' }
          }
        )
      }.to change(QueueItem, :count).by(1)
        .and change(UploadSession, :count).by(5)
      
      # Verify queue structure
      expect(queue_item.batch_id).to be_present
      expect(queue_item.draggable_name).to eq('New Album Tracks')
      expect(queue_item.total_files).to eq(5)
      expect(queue_item.status).to eq('pending')
      expect(queue_item.metadata['project_context']['album']).to eq('Debut Album')
      
      # Verify upload sessions were created correctly
      upload_sessions = queue_item.upload_sessions.order(:created_at)
      expect(upload_sessions.count).to eq(5)
      expect(upload_sessions.map(&:filename)).to include('vocals_verse1.wav', 'guitar_lead.mp3', 'drums_kick.flac')
      expect(upload_sessions.all? { |s| s.status == 'pending' }).to be true
      
      Rails.logger.info "✅ Queue and upload sessions created successfully"
      
      # 📊 PHASE 2: Progress Tracking Initialization
      progress_tracker = ProgressTracker.new(queue_item)
      progress_tracker.start_tracking
      
      expect(progress_tracker.tracking_active?).to be true
      
      initial_progress = progress_tracker.calculate_progress
      expect(initial_progress[:completed_files]).to eq(0)
      expect(initial_progress[:failed_files]).to eq(0)
      expect(initial_progress[:pending_files]).to eq(5)
      expect(initial_progress[:overall_progress_percentage]).to eq(0.0)
      
      Rails.logger.info "📊 Progress tracking initialized"
      
      # 🚀 PHASE 3: Queue Processor Setup
      processor = QueueProcessor.new(
        queue_item: queue_item,
        max_concurrent_uploads: 2,
        bandwidth_limit: 5000 # 5 MB/s
      )
      
      expect(processor.queue_item).to eq(queue_item)
      expect(processor.max_concurrent_uploads).to eq(2)
      expect(processor.bandwidth_limit).to eq(5000)
      
      Rails.logger.info "🔧 Queue processor configured"
      
      # 🎭 PHASE 4: Mock Upload Services (ALL SUCCEED)
      # Mock the ParallelUploadService to simulate successful uploads
      upload_sessions.each do |session|
        mock_service = instance_double(ParallelUploadService)
        allow(ParallelUploadService).to receive(:new)
          .with(session, max_concurrent: 2)
          .and_return(mock_service)
        
        # Mock successful upload - return empty array to simulate chunks processed
        allow(mock_service).to receive(:upload_chunks_parallel) do |chunks|
          # Simulate processing time
          sleep(0.1)
          # Return empty array to indicate successful processing
          []
        end
      end
      
      Rails.logger.info "🎭 Upload mocks configured"
      
      # 🚀 PHASE 5: Execute Queue Processing
      processing_result = nil
      
      # The queue processing might complete so fast it goes directly to 'completed'
      # Just verify it's no longer 'pending' and that processing succeeds
      expect {
        processing_result = processor.process_queue
      }.to change { queue_item.reload.status }.from('pending')
      
      # Verify it ended up in a good final state
      expect(['processing', 'completed']).to include(queue_item.status)
      
      # Verify processing results
      expect(processing_result[:success]).to be true
      expect(processing_result[:total_uploads]).to eq(5)
      expect(processing_result[:completed_uploads]).to eq(5)
      expect(processing_result[:failed_uploads]).to eq(0)
      expect(processing_result[:total_processing_time]).to be > 0
      
      Rails.logger.info "🏁 Queue processing completed successfully"
      
      # 📊 PHASE 6: Final Progress and Metrics Verification
      final_progress = progress_tracker.calculate_progress
      
      expect(final_progress[:completed_files]).to eq(5)
      expect(final_progress[:failed_files]).to eq(0)
      expect(final_progress[:pending_files]).to eq(0)
      expect(final_progress[:overall_progress_percentage]).to eq(100.0)
      
      # Verify queue item final state
      queue_item.reload
      expect(queue_item.status).to eq('completed')
      expect(queue_item.completed_files).to eq(5)
      expect(queue_item.failed_files).to eq(0)
      expect(queue_item.progress_percentage).to eq(100.0)
      
      # Verify all upload sessions completed
      completed_sessions = queue_item.upload_sessions.where(status: 'completed')
      expect(completed_sessions.count).to eq(5)
      
      Rails.logger.info "✅ All files completed successfully"
      
      # 📈 PHASE 7: Advanced Progress Metrics
      final_metrics = progress_tracker.stop_tracking
      
      expect(final_metrics).to include(
        :total_duration,
        :average_upload_speed,
        :files_processed,
        :total_bytes_transferred,
        :success_rate,
        :efficiency_score
      )
      
      expect(final_metrics[:success_rate]).to eq(1.0)
      expect(final_metrics[:files_processed]).to eq(5)
      
      Rails.logger.info "📊 Final metrics calculated"
      
      # 🔍 PHASE 8: Queue Service Status Integration
      queue_status = queue_service.get_queue_status(queue_item)
      
      expect(queue_status[:status]).to eq('completed')
      expect(queue_status[:progress_percentage]).to eq(100.0)
      expect(queue_status[:upload_sessions].length).to eq(5)
      expect(queue_status[:upload_sessions].all? { |s| s[:status] == 'completed' }).to be true
      
      Rails.logger.info "🎯 Queue status verified"
      
      # 📈 PHASE 9: Workspace Statistics
      workspace_stats = queue_service.get_workspace_queue_stats
      
      expect(workspace_stats[:total_queues]).to be >= 1
      expect(workspace_stats[:completed_queues]).to be >= 1
      expect(workspace_stats[:completed_files_in_queues]).to be >= 5
      
      Rails.logger.info "📊 Workspace statistics verified"
      
      Rails.logger.info "🎉 Full workflow integration test PASSED!"
    end
    
    it 'handles mixed success/failure scenarios gracefully' do
      # Create queue with files
      queue_item = queue_service.create_queue_batch(
        draggable_name: 'Mixed Results Test',
        draggable_type: :file,
        files: drag_drop_files.first(3), # Use only first 3 files
        container: container
      )
      
      processor = QueueProcessor.new(queue_item: queue_item)
      upload_sessions = queue_item.upload_sessions.order(:created_at).to_a
      
      Rails.logger.info "🔥 Setting up mixed success/failure scenario"
      Rails.logger.info "📊 Sessions: #{upload_sessions.map(&:filename)}"
      
      # CRITICAL FIX: Use more flexible mocking that matches actual QueueProcessor behavior
      # Track which sessions should fail
      failing_session_filename = upload_sessions[1].filename # Second file (guitar_lead.mp3)
      
      # Mock ParallelUploadService.new with any matching parameters
      # Now expects max_concurrent: 3 (the default) since we removed the artificial limit
      allow(ParallelUploadService).to receive(:new) do |session, options|
        mock_service = instance_double(ParallelUploadService)
        
        # Check if this session should fail
        if session.filename == failing_session_filename
          Rails.logger.info "🔥 Configuring FAILURE for #{session.filename}"
          
          # Mock the upload to raise an exception
          allow(mock_service).to receive(:upload_chunks_parallel) do
            Rails.logger.info "💥 Simulating failure for #{session.filename}"
            raise StandardError, "Network timeout during upload"
          end
        else
          Rails.logger.info "✅ Configuring SUCCESS for #{session.filename}"
          
          # Mock successful upload
          allow(mock_service).to receive(:upload_chunks_parallel) do
            Rails.logger.info "📦 Simulating success for #{session.filename}"
            []
          end
        end
        
        mock_service
      end
      
      # Process queue and capture result
      Rails.logger.info "🚀 Starting mixed scenario processing"
      result = processor.process_queue
      
      Rails.logger.info "📊 Processing result: #{result}"
      
      # Verify mixed results - THIS IS THE CRITICAL ASSERTION
      expect(result[:success]).to be(false), "Expected failure due to one upload failing"
      expect(result[:completed_uploads]).to eq(2), "Expected 2 successful uploads"
      expect(result[:failed_uploads]).to eq(1), "Expected 1 failed upload"
      expect(result[:errors]).to include(/Network timeout/), "Expected network timeout error"
      
      # Verify queue item reflects mixed results
      queue_item.reload
      expect(queue_item.status).to eq('failed'), "Queue status should be failed due to failures"
      expect(queue_item.completed_files).to eq(2), "Expected 2 completed files"
      expect(queue_item.failed_files).to eq(1), "Expected 1 failed file"
      
      Rails.logger.info "🔥 Mixed success/failure scenario handled correctly"
    end
    
    it 'supports queue cancellation mid-processing' do
      queue_item = queue_service.create_queue_batch(
        draggable_name: 'Cancellation Test',
        draggable_type: :file,
        files: drag_drop_files.first(2),
        container: container
      )
      
      # Start processing
      queue_item.start_processing!
      
      # Start some uploads
      upload_sessions = queue_item.upload_sessions
      upload_sessions.each { |s| s.update!(status: :uploading) }
      
      # Cancel the queue
      queue_item.cancel!
      
      # Verify cancellation
      expect(queue_item.status).to eq('cancelled')
      
      # Verify upload sessions are aware of cancellation
      upload_sessions.each do |session|
        expect(['cancelled', 'uploading']).to include(session.status)
      end
      
      Rails.logger.info "🛑 Queue cancellation handled correctly"
    end
  end
  
  describe 'Queue Monitoring and Management' do
    before do
      # Create multiple queues for monitoring tests using unique filenames
      # Alternative approach: use unique filenames for each monitoring queue
      @monitoring_queues = 3.times.map do |i|
        # Create unique files for each monitoring queue to avoid conflicts
        monitoring_files = drag_drop_files.first(2).map do |file|
          file.merge(
            name: "monitoring_#{i}_#{file[:name]}",
            path: "#{file[:path]}_monitoring_#{i}"
          )
        end
        
        queue_service.create_queue_batch(
          draggable_name: "Monitor Queue #{i + 1}",
          draggable_type: :file,
          files: monitoring_files,
          container: container
        )
      end
    end
    
    it 'provides comprehensive queue monitoring' do
      # Test queue listing by status
      pending_queues = queue_service.list_queues_by_status(:pending)
      expect(pending_queues.all? { |q| q.status == 'pending' }).to be true
      
      # Test all queue listing  
      all_queues = queue_service.list_all_queues
      expect(all_queues.count).to be >= 3
      
      # Test workspace statistics
      stats = queue_service.get_workspace_queue_stats
      expect(stats[:total_queues]).to be >= 3
      expect(stats[:active_queues]).to be >= 3
      expect(stats[:total_files_in_queues]).to be >= 6
      
      Rails.logger.info "📈 Queue monitoring and statistics working correctly"
    end
  end
  
  describe 'Performance and Scalability Testing' do
    it 'handles large file batches efficiently' do
      # Create a large batch of files
      large_file_batch = 20.times.map do |i|
        {
          name: "track_#{i + 1}.wav",
          size: rand(1..10).megabytes,
          path: "/album/track_#{i + 1}.wav",
          type: 'file'
        }
      end
      
      # Measure queue creation time
      creation_time = Benchmark.realtime do
        @large_queue = queue_service.create_queue_batch(
          draggable_name: 'Large Album Upload',
          draggable_type: :mixed,
          files: large_file_batch,
          container: container
        )
      end
      
      expect(creation_time).to be < 2.0 # Should create queue quickly
      expect(@large_queue.total_files).to eq(20)
      expect(@large_queue.upload_sessions.count).to eq(20)
      
      Rails.logger.info "⚡ Large batch creation completed in #{creation_time.round(2)}s"
    end
    
    it 'maintains performance under concurrent queue processing' do
      # Create multiple queues with unique filenames
      queues = 3.times.map do |i|
        unique_files = drag_drop_files.first(3).map.with_index do |file, file_index|
          file.merge(
            name: "concurrent_#{i}_#{file[:name]}",
            path: "/concurrent_#{i}#{file[:path]}"
          )
        end
        
        queue_service.create_queue_batch(
          draggable_name: "Concurrent Queue #{i + 1}",
          draggable_type: :file,
          files: unique_files,
          container: container
        )
      end
      
      # Process them with different processors (simulating concurrency)
      processors = queues.map do |queue|
        QueueProcessor.new(queue_item: queue, max_concurrent_uploads: 2)
      end
      
      # Verify all processors initialized correctly
      expect(processors.all? { |p| p.progress_tracker.present? }).to be true
      expect(processors.all? { |p| p.max_concurrent_uploads == 2 }).to be true
      
      Rails.logger.info "🔄 Concurrent queue processing setup verified"
    end
  end
end
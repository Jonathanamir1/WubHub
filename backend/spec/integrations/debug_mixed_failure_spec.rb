# Add this debug test to see what's happening with the mixed failure scenario
# spec/integrations/debug_mixed_failure_spec.rb

require 'rails_helper'

RSpec.describe 'Debug Mixed Failure', type: :integration do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user: user) }
  let(:container) { create(:container, workspace: workspace) }
  let(:queue_service) { UploadQueueService.new(workspace: workspace, user: user) }
  
  let(:test_files) do
    [
      { name: 'file1.mp3', size: 1.megabyte, path: '/file1.mp3', type: 'file' },
      { name: 'file2.wav', size: 2.megabytes, path: '/file2.wav', type: 'file' },
      { name: 'file3.flac', size: 3.megabytes, path: '/file3.flac', type: 'file' }
    ]
  end
  
  it 'debugs mixed success/failure processing' do
    puts "\n🔍 DEBUGGING MIXED SUCCESS/FAILURE"
    
    # Create queue with 3 files
    queue_item = queue_service.create_queue_batch(
      draggable_name: 'Mixed Results Test',
      draggable_type: :file,
      files: test_files,
      container: container
    )
    
    processor = QueueProcessor.new(queue_item: queue_item)
    upload_sessions = queue_item.upload_sessions.to_a
    
    puts "📊 Initial state:"
    puts "  Total sessions: #{upload_sessions.count}"
    upload_sessions.each_with_index do |session, i|
      puts "  Session #{i+1}: #{session.filename} (status: #{session.status})"
    end
    
    # Mock the uploads - first two succeed, third fails
    upload_sessions.each_with_index do |session, index|
      mock_service = instance_double(ParallelUploadService)
      allow(ParallelUploadService).to receive(:new).with(session, max_concurrent: 2).and_return(mock_service)
      
      if index == 1 # Second file fails (index 1)
        puts "🔥 Setting up FAILURE for #{session.filename}"
        allow(mock_service).to receive(:upload_chunks_parallel) do
          # After this error is raised, the session should be in 'uploading' state
          # The error handler should then call session.fail!
          raise StandardError, "Network timeout"
        end
      else
        puts "✅ Setting up SUCCESS for #{session.filename}"
        allow(mock_service).to receive(:upload_chunks_parallel).and_return([])
      end
    end
    
    # Process queue
    puts "\n🚀 Starting processing..."
    result = processor.process_queue
    
    puts "\n📊 Final result:"
    puts "  Success: #{result[:success]}"
    puts "  Total uploads: #{result[:total_uploads]}"
    puts "  Completed uploads: #{result[:completed_uploads]}"
    puts "  Failed uploads: #{result[:failed_uploads]}"
    puts "  Errors: #{result[:errors]}"
    
    # Check final session states
    puts "\n📊 Final session states:"
    upload_sessions.each_with_index do |session, i|
      session.reload
      puts "  Session #{i+1}: #{session.filename} (status: #{session.status})"
    end
    
    # Check queue state
    queue_item.reload
    puts "\n📊 Final queue state:"
    puts "  Queue status: #{queue_item.status}"
    puts "  Completed files: #{queue_item.completed_files}"
    puts "  Failed files: #{queue_item.failed_files}"
    puts "  Pending files: #{queue_item.pending_files}"
    
    # The test expectation
    puts "\n🎯 Test expectation: result[:success] should be FALSE"
    puts "🎯 Actual result: #{result[:success]}"
    
    if result[:success] == true
      puts "❌ PROBLEM: Success is true but should be false"
      puts "❌ This means failed_uploads is 0: #{result[:failed_uploads]}"
    else
      puts "✅ SUCCESS: Mixed failure detected correctly"
    end
  end
end
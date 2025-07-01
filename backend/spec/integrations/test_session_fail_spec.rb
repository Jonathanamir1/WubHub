# Create a simple test to verify session.fail! works
# spec/integrations/test_session_fail_spec.rb

require 'rails_helper'

RSpec.describe 'Test Session Fail', type: :integration do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user: user) }
  let(:container) { create(:container, workspace: workspace) }
  let(:queue_service) { UploadQueueService.new(workspace: workspace, user: user) }
  
  it 'tests that session.fail! updates queue item correctly' do
    puts "\n🔍 TESTING SESSION.FAIL! DIRECTLY"
    
    # Create queue with 1 file
    queue_item = queue_service.create_queue_batch(
      draggable_name: 'Direct Fail Test',
      draggable_type: :file,
      files: [{ name: 'test.mp3', size: 1.megabyte, path: '/test.mp3', type: 'file' }],
      container: container
    )
    
    upload_session = queue_item.upload_sessions.first
    
    puts "📊 Initial state:"
    puts "  Session status: #{upload_session.status}"
    puts "  Queue completed_files: #{queue_item.completed_files}"
    puts "  Queue failed_files: #{queue_item.failed_files}"
    
    # Start the upload to get to 'uploading' state
    upload_session.start_upload!
    puts "📤 After start_upload!:"
    puts "  Session status: #{upload_session.status}"
    
    # Now call fail! directly
    upload_session.fail!
    puts "💥 After fail!:"
    puts "  Session status: #{upload_session.status}"
    
    # Check if queue was updated
    queue_item.reload
    puts "📊 Final queue state:"
    puts "  Queue completed_files: #{queue_item.completed_files}"
    puts "  Queue failed_files: #{queue_item.failed_files}"
    puts "  Queue status: #{queue_item.status}"
    
    # This should work if the callback is properly set up
    expect(upload_session.status).to eq('failed')
    expect(queue_item.failed_files).to eq(1)
    
    puts "✅ Direct session.fail! test PASSED!"
  end
end
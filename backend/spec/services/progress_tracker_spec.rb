# spec/services/progress_tracker_spec.rb
require 'rails_helper'

RSpec.describe ProgressTracker, type: :service do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user: user) }
  let(:queue_item) { create(:queue_item, workspace: workspace, user: user, total_files: 5) }
  let(:tracker) { ProgressTracker.new(queue_item) }

  before do
    # Create upload sessions for testing
    create_list(:upload_session, 5, queue_item: queue_item, workspace: workspace, user: user)
  end

  describe '.initialize' do
    it 'initializes with queue item' do
      expect(tracker.queue_item).to eq(queue_item)
      expect(tracker.start_time).to be_nil
    end

    it 'raises error for nil queue item' do
      expect {
        ProgressTracker.new(nil)
      }.to raise_error(ArgumentError, /queue_item is required/)
    end
  end

  describe '#start_tracking' do
    it 'records start time and initializes metrics' do
      expect {
        tracker.start_tracking
      }.to change { tracker.start_time }.from(nil)

      expect(tracker.metrics).to include(
        :total_bytes_expected,
        :bytes_uploaded,
        :files_completed,
        :files_failed,
        :current_upload_speed,
        :estimated_completion_time
      )
    end

    it 'broadcasts initial progress event' do
      expect(tracker).to receive(:broadcast_progress_update)
      tracker.start_tracking
    end
  end

  describe '#calculate_progress' do
    before { tracker.start_tracking }

    it 'calculates comprehensive progress metrics' do
      # Complete some files
      queue_item.update!(completed_files: 2, failed_files: 1)
      
      progress = tracker.calculate_progress

      expect(progress).to include(
        :queue_id,
        :batch_id,
        :total_files,
        :completed_files,
        :failed_files,
        :pending_files,
        :overall_progress_percentage,
        :current_file_progress,
        :upload_speed_kbps,
        :estimated_completion_time,
        :time_elapsed,
        :bytes_transferred,
        :total_bytes_expected
      )

      expect(progress[:total_files]).to eq(5)
      expect(progress[:completed_files]).to eq(2)
      expect(progress[:failed_files]).to eq(1)
      expect(progress[:pending_files]).to eq(2)
    end

    it 'calculates accurate overall progress percentage' do
      queue_item.update!(completed_files: 3, failed_files: 1)
      
      progress = tracker.calculate_progress
      
      # Progress includes both completed and failed files (4/5 = 80%)
      expect(progress[:overall_progress_percentage]).to eq(80.0)
    end

    it 'tracks bytes transferred vs total expected' do
      # Simulate some upload sessions with progress
      sessions = queue_item.upload_sessions.limit(2)
      sessions.each do |session|
        session.update!(total_size: 10.megabytes, uploaded_size: 5.megabytes)
      end

      progress = tracker.calculate_progress

      expect(progress[:bytes_transferred]).to eq(10.megabytes)
      expect(progress[:total_bytes_expected]).to be > 0
    end
  end

  describe '#calculate_upload_speed' do
    before do
      tracker.start_tracking
      # Simulate some time passage
      tracker.instance_variable_set(:@start_time, 10.seconds.ago)
    end

    it 'calculates current upload speed in KB/s' do
      # Simulate uploaded bytes
      tracker.instance_variable_set(:@last_bytes_snapshot, 1.megabyte)
      tracker.instance_variable_set(:@last_speed_calculation, 5.seconds.ago)

      allow(tracker).to receive(:calculate_total_bytes_transferred).and_return(3.megabytes)

      speed = tracker.calculate_upload_speed

      expect(speed).to be > 0
      expect(speed).to be_a(Numeric)
    end

    it 'returns 0 speed when no data transferred' do
      allow(tracker).to receive(:calculate_total_bytes_transferred).and_return(0)
      
      speed = tracker.calculate_upload_speed
      expect(speed).to eq(0.0)
    end
  end

  describe '#estimate_completion_time' do
    before do
      tracker.start_tracking
      tracker.instance_variable_set(:@start_time, 1.minute.ago)
    end

    it 'estimates completion time based on current progress' do
      queue_item.update!(completed_files: 2, failed_files: 0) # 2/5 completed
      
      estimate = tracker.estimate_completion_time

      expect(estimate).to be > 0
      expect(estimate).to be_a(Numeric) # Should return seconds
    end

    it 'returns 0 when all files are processed' do
      queue_item.update!(completed_files: 4, failed_files: 1) # All 5 files processed
      
      estimate = tracker.estimate_completion_time
      expect(estimate).to eq(0)
    end

    it 'handles cases with no progress gracefully' do
      queue_item.update!(completed_files: 0, failed_files: 0)
      
      estimate = tracker.estimate_completion_time
      expect(estimate).to be >= 0 # Should not be negative
    end
  end

  describe '#get_current_file_progress' do
    it 'returns progress of currently uploading file' do
      # Set one session as currently uploading
      session = queue_item.upload_sessions.first
      session.update!(status: 'uploading', filename: 'current_song.mp3')
      
      current_progress = tracker.get_current_file_progress

      expect(current_progress).to include(
        :filename,
        :status,
        :progress_percentage,
        :bytes_uploaded,
        :total_size
      )

      expect(current_progress[:filename]).to eq('current_song.mp3')
      expect(current_progress[:status]).to eq('uploading')
    end

    it 'returns nil when no file is currently uploading' do
      # All sessions are pending
      queue_item.upload_sessions.update_all(status: 'pending')
      
      current_progress = tracker.get_current_file_progress
      expect(current_progress).to be_nil
    end
  end

  describe '#add_progress_checkpoint' do
    before { tracker.start_tracking }

    it 'records progress checkpoint with timestamp' do
      expect {
        tracker.add_progress_checkpoint(
          completed_files: 2,
          bytes_transferred: 10.megabytes,
          notes: 'Mid-upload checkpoint'
        )
      }.to change { tracker.progress_checkpoints.count }.by(1)

      checkpoint = tracker.progress_checkpoints.last
      expect(checkpoint[:completed_files]).to eq(2)
      expect(checkpoint[:bytes_transferred]).to eq(10.megabytes)
      expect(checkpoint[:timestamp]).to be_a(Time)
      expect(checkpoint[:notes]).to eq('Mid-upload checkpoint')
    end

    it 'limits checkpoint history to prevent memory bloat' do
      # Add many checkpoints
      15.times do |i|
        tracker.add_progress_checkpoint(completed_files: i)
      end

      # Should only keep the most recent ones (default limit is 10)
      expect(tracker.progress_checkpoints.count).to eq(10)
    end
  end

  describe '#progress_trend' do
    before do
      tracker.start_tracking
      
      # Add several checkpoints over time
      [1.minute.ago, 40.seconds.ago, 20.seconds.ago, Time.current].each_with_index do |time, index|
        tracker.add_progress_checkpoint(
          completed_files: index,
          bytes_transferred: index * 5.megabytes,
          timestamp_override: time
        )
      end
    end

    it 'analyzes progress trend (accelerating/decelerating)' do
      trend = tracker.progress_trend

      expect(trend).to include(
        :direction, # :accelerating, :decelerating, :steady
        :files_per_minute,
        :bytes_per_second,
        :trend_confidence
      )

      expect([:accelerating, :decelerating, :steady]).to include(trend[:direction])
      expect(trend[:files_per_minute]).to be >= 0
      expect(trend[:bytes_per_second]).to be >= 0
    end

    it 'returns steady trend when insufficient data' do
      # Clear checkpoints
      tracker.instance_variable_set(:@progress_checkpoints, [])
      
      trend = tracker.progress_trend
      expect(trend[:direction]).to eq(:steady)
      expect(trend[:trend_confidence]).to be < 0.5
    end
  end

  describe '#stop_tracking' do
    before { tracker.start_tracking }

    it 'calculates final metrics and broadcasts completion' do
      expect(tracker).to receive(:broadcast_progress_update).with(hash_including(status: 'completed'))
      
      final_metrics = tracker.stop_tracking

      expect(final_metrics).to include(
        :total_duration,
        :average_upload_speed,
        :files_processed,
        :total_bytes_transferred,
        :final_status
      )

      expect(tracker.tracking_active?).to be false
    end

    it 'handles already stopped tracking gracefully' do
      tracker.stop_tracking
      
      expect {
        tracker.stop_tracking
      }.not_to raise_error
    end
  end

  describe 'real-time progress updates' do
    it 'automatically broadcasts progress when files complete' do
      tracker.start_tracking
      expect(tracker).to receive(:broadcast_progress_update).at_least(:once)

      # Simulate file completion
      queue_item.mark_file_completed!
    end

    it 'throttles broadcast frequency to avoid spam' do
      tracker.start_tracking
      
      # Multiple rapid updates should be throttled
      expect(tracker).to receive(:broadcast_progress_update).at_most(2).times
      
      5.times do
        tracker.send(:maybe_broadcast_update)
        sleep(0.01) # Very rapid updates
      end
    end
  end

  describe 'error handling and edge cases' do
    it 'handles deleted queue items gracefully' do
      tracker.start_tracking
      queue_item.destroy

      expect {
        tracker.calculate_progress
      }.not_to raise_error
    end

    it 'handles concurrent access safely' do
      tracker.start_tracking

      threads = 5.times.map do
        Thread.new do
          10.times { tracker.calculate_progress }
        end
      end

      expect {
        threads.each(&:join)
      }.not_to raise_error
    end

    it 'provides reasonable defaults for corrupted data' do
      # Corrupt the queue item data
      queue_item.update!(total_files: -1, completed_files: 999)
      
      progress = tracker.calculate_progress
      
      expect(progress[:overall_progress_percentage]).to be_between(0, 100)
      expect(progress[:pending_files]).to be >= 0
    end
  end
end
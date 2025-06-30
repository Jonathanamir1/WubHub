# spec/services/enhanced_upload_preflight_service_spec.rb
require 'rails_helper'

RSpec.describe EnhancedUploadPreflightService, type: :service do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user: user) }
  let(:container) { create(:container, workspace: workspace) }

  describe '.preflight_queue_batch' do
    let(:queue_files) do
      [
        { filename: 'drums.wav', size: 5.megabytes, content_type: 'audio/wav', path: '/beats/drums.wav' },
        { filename: 'vocals.mp3', size: 3.megabytes, content_type: 'audio/mpeg', path: '/vocals/vocals.mp3' },
        { filename: 'bass.flac', size: 8.megabytes, content_type: 'audio/flac', path: '/bass/bass.flac' }
      ]
    end

    let(:queue_context) do
      {
        batch_id: SecureRandom.uuid,
        draggable_name: 'Album Tracks',
        draggable_type: 'mixed',
        upload_source: 'drag_drop',
        client_info: { browser: 'Chrome', version: '91.0' }
      }
    end

    it 'performs enhanced preflight for queue-aware batch uploads' do
      result = EnhancedUploadPreflightService.preflight_queue_batch(
        user: user,
        workspace: workspace,
        container: container,
        files_info: queue_files,
        queue_context: queue_context
      )

      expect(result[:overall_valid]).to be true
      expect(result[:queue_optimized]).to be true
      expect(result[:files].length).to eq(3)
      expect(result[:total_size]).to eq(16.megabytes)
      expect(result[:queue_metadata]).to include(
        batch_id: queue_context[:batch_id],
        draggable_name: 'Album Tracks',
        total_files: 3
      )
    end

    it 'provides queue-specific optimization suggestions' do
      result = EnhancedUploadPreflightService.preflight_queue_batch(
        user: user,
        workspace: workspace,
        container: container,
        files_info: queue_files,
        queue_context: queue_context
      )

      expect(result[:optimization_suggestions]).to include(/parallel processing/i)
      expect(result[:optimization_suggestions]).to include(/queue priority/i)
    end

    it 'calculates queue-aware upload estimates' do
      result = EnhancedUploadPreflightService.preflight_queue_batch(
        user: user,
        workspace: workspace,
        container: container,
        files_info: queue_files,
        queue_context: queue_context
      )

      expect(result[:queue_estimates]).to include(
        :parallel_completion_time,
        :sequential_completion_time,
        :recommended_chunk_strategy,
        :priority_order
      )

      # Parallel should be faster than sequential
      expect(result[:queue_estimates][:parallel_completion_time]).to be < result[:queue_estimates][:sequential_completion_time]
    end

    it 'prioritizes smaller files first for queue processing' do
      result = EnhancedUploadPreflightService.preflight_queue_batch(
        user: user,
        workspace: workspace,
        container: container,
        files_info: queue_files,
        queue_context: queue_context
      )

      priority_order = result[:queue_estimates][:priority_order]
      file_sizes = priority_order.map { |p| p[:size] }
      
      # Should be ordered from smallest to largest
      expect(file_sizes).to eq(file_sizes.sort)
      expect(priority_order.first[:filename]).to eq('vocals.mp3') # 3MB - smallest
      expect(priority_order.last[:filename]).to eq('bass.flac')   # 8MB - largest
    end

    it 'detects and handles conflicting filenames within queue' do
      conflicting_files = queue_files + [
        { filename: 'drums.wav', size: 2.megabytes, content_type: 'audio/wav', path: '/other/drums.wav' }
      ]

      result = EnhancedUploadPreflightService.preflight_queue_batch(
        user: user,
        workspace: workspace,
        container: container,
        files_info: conflicting_files,
        queue_context: queue_context
      )

      expect(result[:overall_valid]).to be false
      expect(result[:errors]).to include(/duplicate filename.*drums\.wav/i)
      expect(result[:conflict_resolution]).to include(:suggested_renames)
    end

    it 'provides enhanced chunk strategy for queue context' do
      large_queue_files = [
        { filename: 'master.wav', size: 100.megabytes, content_type: 'audio/wav', path: '/master.wav' },
        { filename: 'stems.zip', size: 250.megabytes, content_type: 'application/zip', path: '/stems.zip' }
      ]

      result = EnhancedUploadPreflightService.preflight_queue_batch(
        user: user,
        workspace: workspace,
        container: container,
        files_info: large_queue_files,
        queue_context: queue_context
      )

      chunk_strategy = result[:queue_estimates][:recommended_chunk_strategy]
      expect(chunk_strategy).to include(
        :total_chunks,
        :parallel_chunk_groups,
        :estimated_bandwidth_usage,
        :optimal_concurrent_uploads
      )

      expect(chunk_strategy[:optimal_concurrent_uploads]).to be > 1
      expect(chunk_strategy[:parallel_chunk_groups]).to be_an(Array)
    end

    it 'validates queue metadata and context' do
      invalid_context = queue_context.merge(draggable_type: 'invalid_type')

      result = EnhancedUploadPreflightService.preflight_queue_batch(
        user: user,
        workspace: workspace,
        container: container,
        files_info: queue_files,
        queue_context: invalid_context
      )

      expect(result[:overall_valid]).to be false
      expect(result[:errors]).to include(/invalid draggable_type/i)
    end

    it 'handles empty queue gracefully' do
      result = EnhancedUploadPreflightService.preflight_queue_batch(
        user: user,
        workspace: workspace,
        container: container,
        files_info: [],
        queue_context: queue_context.merge(draggable_name: 'Empty Folder')
      )

      expect(result[:overall_valid]).to be true
      expect(result[:queue_metadata][:total_files]).to eq(0)
      expect(result[:queue_estimates][:parallel_completion_time]).to eq(0)
    end
  end

  describe '.detect_queue_context' do
    it 'detects queue context from file paths and metadata' do
      files_with_structure = [
        { filename: 'track1.mp3', size: 3.megabytes, path: '/Album/track1.mp3' },
        { filename: 'track2.mp3', size: 3.megabytes, path: '/Album/track2.mp3' },
        { filename: 'cover.jpg', size: 500.kilobytes, path: '/Album/cover.jpg' }
      ]

      context = EnhancedUploadPreflightService.detect_queue_context(files_with_structure)

      expect(context[:inferred_draggable_type]).to eq('folder')
      expect(context[:common_path]).to eq('/Album')
      expect(context[:suggested_draggable_name]).to eq('Album')
      expect(context[:file_type_distribution]).to include(
        'audio' => 2,
        'image' => 1
      )
    end

    it 'detects mixed content types' do
      mixed_files = [
        { filename: 'song.mp3', size: 3.megabytes, path: '/song.mp3' },
        { filename: 'project.logicx', size: 50.megabytes, path: '/project.logicx' },
        { filename: 'notes.pdf', size: 1.megabyte, path: '/notes.pdf' }
      ]

      context = EnhancedUploadPreflightService.detect_queue_context(mixed_files)

      expect(context[:inferred_draggable_type]).to eq('mixed')
      expect(context[:file_type_distribution]).to include(
        'audio' => 1,
        'project' => 1,
        'document' => 1
      )
    end

    it 'provides smart naming suggestions' do
      project_files = [
        { filename: 'MyProject.logicx', size: 50.megabytes, path: '/MyProject.logicx' },
        { filename: 'MyProject Bounce.wav', size: 30.megabytes, path: '/MyProject Bounce.wav' }
      ]

      context = EnhancedUploadPreflightService.detect_queue_context(project_files)

      expect(context[:suggested_draggable_name]).to eq('MyProject')
      expect(context[:naming_confidence]).to be > 0.8
    end
  end

  describe '.optimize_upload_order' do
    let(:mixed_size_files) do
      [
        { filename: 'huge.wav', size: 100.megabytes, upload_time_estimate: 120 },
        { filename: 'small.mp3', size: 2.megabytes, upload_time_estimate: 5 },
        { filename: 'medium.flac', size: 20.megabytes, upload_time_estimate: 25 },
        { filename: 'tiny.jpg', size: 500.kilobytes, upload_time_estimate: 2 }
      ]
    end

    it 'prioritizes smaller files for faster user feedback' do
      optimized_order = EnhancedUploadPreflightService.optimize_upload_order(
        mixed_size_files,
        strategy: :smallest_first
      )

      filenames = optimized_order.map { |f| f[:filename] }
      expect(filenames).to eq(['tiny.jpg', 'small.mp3', 'medium.flac', 'huge.wav'])
    end

    it 'provides interleaved strategy for mixed file sizes' do
      optimized_order = EnhancedUploadPreflightService.optimize_upload_order(
        mixed_size_files,
        strategy: :interleaved
      )

      # Should alternate between small and large files for optimal user experience
      expect(optimized_order.first[:filename]).to eq('tiny.jpg')    # Fastest feedback
      expect(optimized_order.second[:filename]).to eq('huge.wav')   # Start large file early
      expect(optimized_order.third[:filename]).to eq('small.mp3')   # Quick win
    end

    it 'considers file type priorities for audio-first strategy' do
      optimized_order = EnhancedUploadPreflightService.optimize_upload_order(
        mixed_size_files,
        strategy: :audio_priority
      )

      audio_files = optimized_order.select { |f| f[:filename].match?(/\.(mp3|wav|flac)$/i) }
      non_audio_files = optimized_order.select { |f| !f[:filename].match?(/\.(mp3|wav|flac)$/i) }

      # Audio files should come first in the optimized order
      expect(optimized_order.first(3).map { |f| f[:filename] }).to all(match(/\.(mp3|wav|flac)$/i))
    end
  end

  describe '.calculate_parallel_efficiency' do
    it 'calculates optimal parallel upload configuration' do
      files_for_parallel = [
        { size: 10.megabytes, chunks_count: 2 },
        { size: 20.megabytes, chunks_count: 4 },
        { size: 5.megabytes, chunks_count: 1 },
        { size: 30.megabytes, chunks_count: 6 }
      ]

      efficiency = EnhancedUploadPreflightService.calculate_parallel_efficiency(
        files_for_parallel,
        max_concurrent_uploads: 3,
        bandwidth_limit: 10_000 # 10 MB/s
      )

      expect(efficiency).to include(
        :recommended_concurrency,
        :bandwidth_per_stream,
        :estimated_completion_time,
        :efficiency_score
      )

      expect(efficiency[:recommended_concurrency]).to be <= 3
      expect(efficiency[:efficiency_score]).to be_between(0, 1)
    end

    it 'handles bandwidth constraints appropriately' do
      # High bandwidth scenario
      high_bandwidth = EnhancedUploadPreflightService.calculate_parallel_efficiency(
        [{ size: 100.megabytes, chunks_count: 20 }],
        max_concurrent_uploads: 5,
        bandwidth_limit: 50_000 # 50 MB/s
      )

      # Low bandwidth scenario  
      low_bandwidth = EnhancedUploadPreflightService.calculate_parallel_efficiency(
        [{ size: 100.megabytes, chunks_count: 20 }],
        max_concurrent_uploads: 5,
        bandwidth_limit: 1_000 # 1 MB/s
      )

      expect(high_bandwidth[:recommended_concurrency]).to be >= low_bandwidth[:recommended_concurrency]
      expect(high_bandwidth[:estimated_completion_time]).to be < low_bandwidth[:estimated_completion_time]
    end
  end

  describe '.validate_queue_constraints' do
    it 'validates queue-specific business rules' do
      large_queue_context = {
        batch_id: SecureRandom.uuid,
        draggable_name: 'Massive Project',
        draggable_type: 'folder',
        total_size: 5.gigabytes,
        file_count: 200
      }

      validation = EnhancedUploadPreflightService.validate_queue_constraints(
        large_queue_context,
        workspace: workspace
      )

      expect(validation).to include(:valid, :warnings, :recommendations)
      
      if validation[:warnings].any?
        expect(validation[:warnings]).to include(/large batch/i)
      end
    end

    it 'enforces maximum files per queue limits' do
      massive_queue_context = {
        batch_id: SecureRandom.uuid,
        draggable_name: 'Too Many Files',
        draggable_type: 'folder',
        file_count: 1000 # Excessive
      }

      validation = EnhancedUploadPreflightService.validate_queue_constraints(
        massive_queue_context,
        workspace: workspace
      )

      expect(validation[:valid]).to be false
      expect(validation[:errors]).to include(/too many files/i)
    end

    it 'provides splitting recommendations for oversized queues' do
      huge_queue_context = {
        batch_id: SecureRandom.uuid,
        draggable_name: 'Huge Project',
        draggable_type: 'folder',
        total_size: 20.gigabytes,
        file_count: 500
      }

      validation = EnhancedUploadPreflightService.validate_queue_constraints(
        huge_queue_context,
        workspace: workspace
      )

      expect(validation[:recommendations]).to include(/split.*smaller batches/i)
      expect(validation[:suggested_batch_size]).to be_present
    end
  end

  describe 'integration with existing UploadPreflightService' do
    it 'falls back to standard preflight for non-queue uploads' do
      single_file = {
        filename: 'single.mp3',
        size: 5.megabytes,
        content_type: 'audio/mpeg'
      }

      # Should delegate to existing service for single file uploads
      result = EnhancedUploadPreflightService.preflight_upload(
        user: user,
        workspace: workspace,
        container: container,
        file_info: single_file
      )

      expect(result[:valid]).to be true
      expect(result[:filename]).to eq('single.mp3')
      expect(result[:queue_optimized]).to be_falsy # Not queue-optimized
    end

    it 'enhances existing batch preflight with queue features' do
      batch_files = [
        { filename: 'track1.mp3', size: 3.megabytes, content_type: 'audio/mpeg' },
        { filename: 'track2.mp3', size: 4.megabytes, content_type: 'audio/mpeg' }
      ]

      # Enhanced batch should provide all standard features plus queue enhancements
      result = EnhancedUploadPreflightService.preflight_batch(
        user: user,
        workspace: workspace,
        container: container,
        files_info: batch_files
      )

      # Standard batch features
      expect(result[:overall_valid]).to be true
      expect(result[:total_size]).to eq(7.megabytes)
      
      # Enhanced features when queue context available
      expect(result[:queue_suggestions]).to be_present
      expect(result[:optimized_upload_order]).to be_present
    end
  end
end
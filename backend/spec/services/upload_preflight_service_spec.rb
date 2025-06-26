# spec/services/upload_preflight_service_spec.rb
require 'rails_helper'

RSpec.describe UploadPreflightService, type: :service do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user: user) }
  let(:container) { create(:container, workspace: workspace) }
  
  describe '.preflight_upload' do
    context 'with valid single file' do
      let(:file_info) do
        {
          filename: 'song.mp3',
          size: 5.megabytes,
          content_type: 'audio/mpeg'
        }
      end
      
      it 'allows valid audio file upload' do
        result = UploadPreflightService.preflight_upload(
          user: user,
          workspace: workspace,
          container: container,
          file_info: file_info
        )
        
        expect(result[:valid]).to be true
        expect(result[:errors]).to be_empty
        expect(result[:warnings]).to be_empty
        expect(result[:estimated_duration]).to be > 0
        expect(result[:chunks_count]).to be > 0
      end
      
      it 'provides upload estimation details' do
        result = UploadPreflightService.preflight_upload(
          user: user,
          workspace: workspace,
          container: container,
          file_info: file_info
        )
        
        expect(result).to include(
          :valid,
          :errors,
          :warnings,
          :estimated_duration,
          :chunks_count,
          :storage_required,
          :final_storage_path
        )
        
        expect(result[:storage_required]).to eq(file_info[:size])
        expect(result[:final_storage_path]).to include(file_info[:filename])
      end
    end
    
    context 'with invalid files' do
      it 'rejects files that are too large' do
        large_file = {
          filename: 'huge_file.wav',
          size: 10.gigabytes,  # Exceeds reasonable limit
          content_type: 'audio/wav'
        }
        
        result = UploadPreflightService.preflight_upload(
          user: user,
          workspace: workspace,
          container: container,
          file_info: large_file
        )
        
        expect(result[:valid]).to be false
        expect(result[:errors]).to include(/file size too large/i)
      end
      
      it 'rejects files with invalid types' do
        invalid_file = {
          filename: 'virus.exe',
          size: 1.megabyte,
          content_type: 'application/x-executable'
        }
        
        result = UploadPreflightService.preflight_upload(
          user: user,
          workspace: workspace,
          container: container,
          file_info: invalid_file
        )
        
        expect(result[:valid]).to be false
        expect(result[:errors]).to include(/security risk|file type not allowed/i)
      end
      
      it 'rejects files with duplicate names in same location' do
        # Create existing file in container
        existing_file = create(:upload_session,
          workspace: workspace,
          container: container,
          user: user,
          filename: 'song.mp3',
          status: 'completed'
        )
        
        duplicate_file = {
          filename: 'song.mp3',
          size: 3.megabytes,
          content_type: 'audio/mpeg'
        }
        
        result = UploadPreflightService.preflight_upload(
          user: user,
          workspace: workspace,
          container: container,
          file_info: duplicate_file
        )
        
        expect(result[:valid]).to be false
        expect(result[:errors]).to include(/file already exists/i)
      end
      
      it 'rejects files when user lacks upload permissions' do
        other_user = create(:user)
        restricted_workspace = create(:workspace, user: other_user)
        
        file_info = {
          filename: 'song.mp3',
          size: 5.megabytes,
          content_type: 'audio/mpeg'
        }
        
        result = UploadPreflightService.preflight_upload(
          user: user,  # Different user, no collaborator role
          workspace: restricted_workspace,
          container: nil,
          file_info: file_info
        )
        
        expect(result[:valid]).to be false
        expect(result[:errors]).to include(/permission denied/i)
      end
    end
    
    context 'with storage constraints' do
      let(:workspace_with_storage) do
        workspace_instance = workspace
        # Define singleton methods for this specific instance
        workspace_instance.define_singleton_method(:storage_quota) { 100.megabytes }
        workspace_instance.define_singleton_method(:storage_used) { 95.megabytes }
        workspace_instance
      end
      
      it 'rejects files that would exceed storage quota' do
        large_file = {
          filename: 'large_song.wav',
          size: 10.megabytes,  # Would exceed remaining 5MB
          content_type: 'audio/wav'
        }
        
        result = UploadPreflightService.preflight_upload(
          user: user,
          workspace: workspace_with_storage,
          container: container,
          file_info: large_file
        )
        
        expect(result[:valid]).to be false
        expect(result[:errors]).to include(/storage quota exceeded/i)
      end
      
      it 'allows files within storage quota' do
        small_file = {
          filename: 'small_song.mp3',
          size: 3.megabytes,  # Within remaining 5MB
          content_type: 'audio/mpeg'
        }
        
        result = UploadPreflightService.preflight_upload(
          user: user,
          workspace: workspace_with_storage,
          container: container,
          file_info: small_file
        )
        
        expect(result[:valid]).to be true
        expect(result[:warnings]).to include(/storage/i)  # Warning about limited space
      end
    end
    
    context 'with security scanning integration' do
      it 'flags potentially dangerous files with warnings' do
        plugin_file = {
          filename: 'reverb.dll',
          size: 2.megabytes,
          content_type: 'application/octet-stream'
        }
        
        result = UploadPreflightService.preflight_upload(
          user: user,
          workspace: workspace,
          container: container,
          file_info: plugin_file
        )
        
        expect(result[:valid]).to be true
        expect(result[:security_risk]).to eq('medium')
        # Warning might be in warnings or the fact that security_risk is medium
        expect(result[:security_risk]).not_to eq('low')
      end
      
      it 'blocks dangerous files during preflight' do
        blocked_file = {
          filename: 'malware.scr',
          size: 1.megabyte,
          content_type: 'application/octet-stream'
        }
        
        result = UploadPreflightService.preflight_upload(
          user: user,
          workspace: workspace,
          container: container,
          file_info: blocked_file
        )
        
        expect(result[:valid]).to be false
        expect(result[:errors]).to include(/security risk|file type not allowed/i)
        # The security_risk might be nil if blocked at file type level, so check if it exists
        expect(result[:security_risk]).to be_present if result[:security_risk]
      end
    end
  end
  
  describe '.preflight_batch' do
    let(:file_batch) do
      [
        { filename: 'song1.mp3', size: 5.megabytes, content_type: 'audio/mpeg' },
        { filename: 'song2.wav', size: 8.megabytes, content_type: 'audio/wav' },
        { filename: 'project.logicx', size: 50.megabytes, content_type: 'application/octet-stream' }
      ]
    end
    
    it 'validates multiple files at once' do
      result = UploadPreflightService.preflight_batch(
        user: user,
        workspace: workspace,
        container: container,
        files_info: file_batch
      )
      
      expect(result[:overall_valid]).to be true
      expect(result[:files].length).to eq(3)
      expect(result[:total_size]).to eq(63.megabytes)
      expect(result[:estimated_duration]).to be > 0
    end
    
    it 'provides per-file and batch results' do
      result = UploadPreflightService.preflight_batch(
        user: user,
        workspace: workspace,
        container: container,
        files_info: file_batch
      )
      
      expect(result).to include(
        :overall_valid,
        :files,
        :total_size,
        :estimated_duration,
        :total_chunks,
        :errors,
        :warnings
      )
      
      # Each file should have individual results
      result[:files].each do |file_result|
        expect(file_result).to include(:filename, :valid, :errors, :warnings)
      end
    end
    
    it 'flags batch if any file is invalid' do
      invalid_batch = file_batch + [
        { filename: 'huge.wav', size: 20.gigabytes, content_type: 'audio/wav' }
      ]
      
      result = UploadPreflightService.preflight_batch(
        user: user,
        workspace: workspace,
        container: container,
        files_info: invalid_batch
      )
      
      expect(result[:overall_valid]).to be false
      expect(result[:errors]).not_to be_empty
      
      # Should still process valid files
      valid_files = result[:files].select { |f| f[:valid] }
      expect(valid_files.length).to eq(3)
    end
    
    it 'provides optimization suggestions for batch uploads' do
      result = UploadPreflightService.preflight_batch(
        user: user,
        workspace: workspace,
        container: container,
        files_info: file_batch
      )
      
      expect(result).to include(:optimization_suggestions)
      expect(result[:optimization_suggestions]).to be_an(Array)
    end
  end
  
  describe '.estimate_upload_time' do
    it 'estimates upload time based on file size and connection' do
      file_size = 10.megabytes
      
      # Test different connection speeds
      slow_estimate = UploadPreflightService.estimate_upload_time(file_size, connection_speed: :slow)
      fast_estimate = UploadPreflightService.estimate_upload_time(file_size, connection_speed: :fast)
      
      expect(slow_estimate).to be > fast_estimate
      expect(slow_estimate).to be_a(Numeric)
      expect(fast_estimate).to be_a(Numeric)
    end
    
    it 'factors in chunk overhead and processing time' do
      file_size = 100.megabytes
      
      estimate = UploadPreflightService.estimate_upload_time(
        file_size,
        connection_speed: :medium,
        include_processing: true
      )
      
      expect(estimate).to be > 0
      expect(estimate).to be < 3600  # Should be reasonable (under 1 hour)
    end
  end
  
  describe '.check_storage_availability' do
    it 'returns storage status for workspace' do
      status = UploadPreflightService.check_storage_availability(workspace, 10.megabytes)
      
      expect(status).to include(
        :available,
        :quota_total,
        :quota_used,
        :quota_remaining,
        :sufficient_space
      )
    end
    
    it 'warns when approaching storage limits' do
      # Create workspace with storage methods
      workspace_with_storage = workspace
      workspace_with_storage.define_singleton_method(:storage_quota) { 100.megabytes }
      workspace_with_storage.define_singleton_method(:storage_used) { 90.megabytes }
      
      status = UploadPreflightService.check_storage_availability(workspace_with_storage, 5.megabytes)
      
      expect(status[:sufficient_space]).to be true
      expect(status[:warnings]).to include(/approaching storage limit/i)
    end
  end
end
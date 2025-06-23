# spec/services/virus_scanner_service_spec.rb
require 'rails_helper'

# Create stub job classes for testing
class VirusScanJob < ApplicationJob
  def perform(upload_session_id)
    # Stub implementation for tests
  end
end

class FinalizeUploadJob < ApplicationJob
  def perform(upload_session_id)
    # Stub implementation for tests
  end
end

RSpec.describe VirusScannerService, type: :service do
  # Configure ActiveJob for testing
  before(:all) do
    ActiveJob::Base.queue_adapter = :test
  end
  
  before(:each) do
    # Clear jobs before each test
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
  end
  let(:service) { described_class.new }
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user: user) }
  let(:container) { create(:container, workspace: workspace) }
  
  describe '#scan_assembled_file_async' do
    let(:upload_session) do
      # Create upload session without virus scanning fields first
      session = create(:upload_session,
        workspace: workspace,
        container: container,
        user: user,
        filename: 'test_audio.mp3',
        total_size: 1024,
        chunks_count: 1,
        status: 'assembling'
      )
      
      # Manually add the fields we need for testing
      session.define_singleton_method(:assembled_file_path) { '/tmp/uploads/test_audio.mp3' }
      session.define_singleton_method(:assembled_file_path=) { |value| @assembled_file_path = value }
      session.define_singleton_method(:virus_scan_queued_at) { @virus_scan_queued_at }
      session.define_singleton_method(:virus_scan_queued_at=) { |value| @virus_scan_queued_at = value }
      session.define_singleton_method(:virus_scan_completed_at) { @virus_scan_completed_at }
      session.define_singleton_method(:virus_scan_completed_at=) { |value| @virus_scan_completed_at = value }
      
      # Allow virus scanning statuses
      allow(session).to receive(:update!).and_call_original
      allow(session).to receive(:update!) do |attributes|
        if attributes[:status] == 'virus_scanning'
          session.instance_variable_set(:@status, 'virus_scanning')
          session.virus_scan_queued_at = attributes[:virus_scan_queued_at] if attributes[:virus_scan_queued_at]
        elsif attributes[:status] == 'finalizing'
          session.instance_variable_set(:@status, 'finalizing')
          session.virus_scan_completed_at = attributes[:virus_scan_completed_at] if attributes[:virus_scan_completed_at]
        elsif attributes[:status] == 'virus_detected'
          session.instance_variable_set(:@status, 'virus_detected')
          session.virus_scan_completed_at = attributes[:virus_scan_completed_at] if attributes[:virus_scan_completed_at]
        elsif attributes[:status] == 'completed'
          session.instance_variable_set(:@status, 'completed')
        else
          session.update_columns(attributes.except(:virus_scan_queued_at, :virus_scan_completed_at))
        end
      end
      
      # Mock status method to return our custom status
      allow(session).to receive(:status) do
        session.instance_variable_get(:@status) || session.read_attribute(:status)
      end
      
      # Ensure metadata is initialized
      session.metadata = {} unless session.metadata
      
      session
    end
    
    context 'when ClamAV is available and running' do
      before do
        # Mock ClamAV service availability
        allow(service).to receive(:clamav_available?).and_return(true)
        # Mock file existence
        allow(File).to receive(:exist?).with(upload_session.assembled_file_path).and_return(true)
      end
      
      it 'enqueues virus scan job for assembled file' do
        expect {
          service.scan_assembled_file_async(upload_session)
        }.to have_enqueued_job(VirusScanJob).with(upload_session.id)
      end
      
      it 'transitions upload session to virus_scanning status' do
        service.scan_assembled_file_async(upload_session)
        
        expect(upload_session.status).to eq('virus_scanning')
        expect(upload_session.virus_scan_queued_at).to be_within(1.second).of(Time.current)
      end
      
      it 'updates upload session metadata with scan info' do
        service.scan_assembled_file_async(upload_session)
        
        upload_session.reload
        virus_scan_metadata = upload_session.metadata['virus_scan']
        expect(virus_scan_metadata['scanner']).to eq('clamav')
        expect(virus_scan_metadata['status']).to eq('scanning')
        expect(Time.parse(virus_scan_metadata['queued_at'])).to be_within(1.second).of(Time.current)
      end
    end
    
    context 'when ClamAV is not available' do
      before do
        allow(service).to receive(:clamav_available?).and_return(false)
        allow(File).to receive(:exist?).with(upload_session.assembled_file_path).and_return(true)
      end
      
      it 'marks upload session as virus_scan_unavailable and allows completion' do
        service.scan_assembled_file_async(upload_session)
        
        expect(upload_session.status).to eq('completed')
        expect(upload_session.metadata['virus_scan']['status']).to eq('unavailable')
        expect(upload_session.metadata['virus_scan']['error']).to include('ClamAV not available')
      end
      
      it 'does not enqueue virus scan job' do
        expect {
          service.scan_assembled_file_async(upload_session)
        }.not_to have_enqueued_job(VirusScanJob)
      end
    end
    
    context 'with invalid upload session' do
      it 'raises error for upload session without assembled file path' do
        upload_session.define_singleton_method(:assembled_file_path) { nil }
        
        expect {
          service.scan_assembled_file_async(upload_session)
        }.to raise_error(VirusScannerService::InvalidFileError, /assembled_file_path is required/)
      end
      
      it 'raises error for non-assembling status' do
        allow(upload_session).to receive(:status).and_return('pending')
        
        expect {
          service.scan_assembled_file_async(upload_session)
        }.to raise_error(VirusScannerService::InvalidStatusError, /must be in assembling status/)
      end
      
      it 'raises error if assembled file does not exist' do
        allow(File).to receive(:exist?).with('/tmp/uploads/test_audio.mp3').and_return(false)
        
        expect {
          service.scan_assembled_file_async(upload_session)
        }.to raise_error(VirusScannerService::FileNotFoundError, /Assembled file not found/)
      end
    end
  end
  
  describe '#scan_file_sync' do
    let(:temp_file_path) { Rails.root.join('tmp', 'test_file.txt') }
    let(:clean_content) { 'This is a clean test file content' }
    let(:virus_content) { 'X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' }
    
    before do
      allow(service).to receive(:clamav_available?).and_return(true)
      # Mock the ClamAV execution since we don't have it installed in test environment
      allow(service).to receive(:execute_clamav_scan).and_return({
        output: "#{temp_file_path}: OK",
        exit_code: 0
      })
      # Ensure temp directory exists
      FileUtils.mkdir_p(Rails.root.join('tmp'))
    end
    
    after do
      # Clean up actual files if they exist (convert Pathname to string)
      temp_file_string = temp_file_path.to_s
      File.delete(temp_file_string) if File.exist?(temp_file_string)
    end
    
    context 'with clean file' do
      before do
        File.write(temp_file_path, clean_content)
      end
      
      it 'returns clean scan result' do
        result = service.scan_file_sync(temp_file_path)
        
        expect(result.clean?).to be true
        expect(result.infected?).to be false
        expect(result.virus_name).to be_nil
        expect(result.scanner).to eq('clamav')
        expect(result.scan_duration).to be > 0
        expect(result.file_size).to eq(clean_content.bytesize)
      end
    end
    
    context 'with infected file (EICAR test virus)' do
      before do
        File.write(temp_file_path, virus_content)
        # Mock infected file result
        allow(service).to receive(:execute_clamav_scan).and_return({
          output: "#{temp_file_path}: EICAR-Test-File FOUND",
          exit_code: 1
        })
      end
      
      it 'detects virus and returns infected result' do
        result = service.scan_file_sync(temp_file_path)
        
        expect(result.clean?).to be false
        expect(result.infected?).to be true
        expect(result.virus_name).to include('EICAR')
        expect(result.scanner).to eq('clamav')
        expect(result.scan_duration).to be > 0
        expect(result.file_size).to eq(virus_content.bytesize)
      end
    end
    
    context 'with large file (timeout test)' do
      let(:large_file_path) { Rails.root.join('tmp', 'large_test_file.dat').to_s }
      
      before do
        # Create a large file (simulated)
        allow(File).to receive(:size).with(large_file_path).and_return(100.megabytes)
        allow(File).to receive(:exist?).with(large_file_path).and_return(true)
        # Allow the regular temp file operations to continue normally
        allow(File).to receive(:exist?).with(temp_file_path.to_s).and_call_original
        # Don't actually create the large file, just mock its existence
      end
      
      it 'respects timeout configuration' do
        # Mock a slow scan that times out
        allow(service).to receive(:execute_clamav_scan).and_raise(Timeout::Error)
        
        expect {
          service.scan_file_sync(large_file_path)
        }.to raise_error(VirusScannerService::ScanTimeoutError, /Virus scan timed out/)
      end
    end
    
    context 'with non-existent file' do
      it 'raises file not found error' do
        expect {
          service.scan_file_sync('/non/existent/file.txt')
        }.to raise_error(VirusScannerService::FileNotFoundError)
      end
    end
    
    context 'when ClamAV is not running' do
      before do
        allow(service).to receive(:clamav_available?).and_return(false)
      end
      
      it 'raises scanner unavailable error' do
        File.write(temp_file_path, clean_content)
        
        expect {
          service.scan_file_sync(temp_file_path)
        }.to raise_error(VirusScannerService::ScannerUnavailableError)
      end
    end
  end
  
  describe '#handle_scan_result' do
    let(:upload_session) do
      session = create(:upload_session,
        workspace: workspace,
        container: container,
        user: user,
        filename: 'test_audio.mp3',
        total_size: 1024,
        chunks_count: 1,
        status: 'assembling' # Start with assembling, we'll mock the virus_scanning state
      )
      
      # Add virus scanning fields
      session.define_singleton_method(:assembled_file_path) { '/tmp/uploads/test_audio.mp3' }
      session.define_singleton_method(:virus_scan_completed_at) { @virus_scan_completed_at }
      session.define_singleton_method(:virus_scan_completed_at=) { |value| @virus_scan_completed_at = value }
      
      # Mock the status to be virus_scanning initially
      session.instance_variable_set(:@status, 'virus_scanning')
      allow(session).to receive(:status) do
        session.instance_variable_get(:@status) || session.read_attribute(:status)
      end
      
      # Initialize metadata properly
      session.metadata = {} unless session.metadata
      
      # Allow updates with virus scanning statuses
      allow(session).to receive(:update!).and_call_original
      allow(session).to receive(:update!) do |attributes|
        if attributes[:status] == 'finalizing'
          session.instance_variable_set(:@status, 'finalizing')
        elsif attributes[:status] == 'virus_detected'
          session.instance_variable_set(:@status, 'virus_detected')
        end
        session.virus_scan_completed_at = attributes[:virus_scan_completed_at] if attributes[:virus_scan_completed_at]
        # Update metadata if present  
        if attributes.key?(:metadata)
          session.metadata = attributes[:metadata]
        end
      end
      
      # Mock save! to update metadata
      allow(session).to receive(:save!) do
        # Just return true - metadata updates happen in memory for our test
        true
      end
      
      # Mock transaction to just yield the block
      allow(session).to receive(:transaction).and_yield
      
      session
    end
    
    context 'with clean scan result' do
      let(:clean_result) do
        VirusScannerService::ScanResult.new(
          clean: true,
          virus_name: nil,
          scanner: 'clamav',
          scan_duration: 0.15,
          file_size: 1024
        )
      end
      
      it 'completes upload session successfully' do
        expect {
          service.handle_scan_result(upload_session, clean_result)
        }.to have_enqueued_job(FinalizeUploadJob).with(upload_session.id)
        
        expect(upload_session.status).to eq('finalizing')
        expect(upload_session.virus_scan_completed_at).to be_within(1.second).of(Time.current)
        expect(upload_session.metadata['virus_scan']['status']).to eq('clean')
      end
    end
    
    context 'with infected scan result' do
      let(:infected_result) do
        VirusScannerService::ScanResult.new(
          clean: false,
          virus_name: 'EICAR-Test-File',
          scanner: 'clamav',
          scan_duration: 0.23,
          file_size: 1024
        )
      end
      
      it 'blocks upload and cleans up infected file' do
        # Mock File operations for cleanup
        expect(File).to receive(:exist?).with(upload_session.assembled_file_path).and_return(true)
        expect(File).to receive(:delete).with(upload_session.assembled_file_path).and_return(true)
        
        service.handle_scan_result(upload_session, infected_result)
        
        expect(upload_session.status).to eq('virus_detected')
        expect(upload_session.virus_scan_completed_at).to be_within(1.second).of(Time.current)
        expect(upload_session.metadata['virus_scan']).to include(
          'status' => 'infected',
          'virus_name' => 'EICAR-Test-File',
          'scanner' => 'clamav'
        )
      end
      
      it 'handles cleanup errors gracefully' do
        allow(File).to receive(:delete).and_raise(Errno::ENOENT)
        
        expect {
          service.handle_scan_result(upload_session, infected_result)
        }.not_to raise_error
        
        expect(upload_session.status).to eq('virus_detected')
      end
    end
  end
  
  describe '#clamav_available?' do
    context 'when ClamAV daemon is running' do
      before do
        # Mock successful connection to ClamAV daemon
        mock_socket = double('socket')
        allow(mock_socket).to receive(:write).with("PING\n")
        allow(mock_socket).to receive(:gets).and_return("PONG\n")
        allow(mock_socket).to receive(:close)
        allow(TCPSocket).to receive(:new).with('localhost', 3310).and_return(mock_socket)
      end
      
      it 'returns true when daemon responds to PING' do
        expect(service.clamav_available?).to be true
      end
    end
    
    context 'when ClamAV daemon is not running' do
      before do
        # Mock failed connection
        allow(TCPSocket).to receive(:new).with('localhost', 3310).and_raise(Errno::ECONNREFUSED)
        # Also mock the fallback command to fail
        allow(service).to receive(:system).with('which clamscan 2>/dev/null >/dev/null').and_return(false)
      end
      
      it 'returns false and logs warning' do
        expect(Rails.logger).to receive(:warn).with(/ClamAV daemon not reachable/)
        expect(service.clamav_available?).to be false
      end
    end
    
    context 'when checking via command line fallback' do
      before do
        # Mock TCPSocket failure but command line success
        allow(TCPSocket).to receive(:new).and_raise(Errno::ECONNREFUSED)
        allow(Rails.logger).to receive(:warn)
      end
      
      it 'returns true if clamscan command exists' do
        # Mock the system command execution instead of $?
        allow(service).to receive(:`).with('which clamscan 2>/dev/null').and_return('/usr/bin/clamscan')
        allow(service).to receive(:system).with('which clamscan 2>/dev/null >/dev/null').and_return(true)
        
        expect(service.clamav_available?).to be true
      end
      
      it 'returns false if clamscan command does not exist' do
        allow(service).to receive(:`).with('which clamscan 2>/dev/null').and_return('')
        allow(service).to receive(:system).with('which clamscan 2>/dev/null >/dev/null').and_return(false)
        
        expect(service.clamav_available?).to be false
      end
    end
  end
  
  describe 'ScanResult' do
    describe '#initialize' do
      it 'creates result with required attributes' do
        result = VirusScannerService::ScanResult.new(
          clean: true,
          virus_name: nil,
          scanner: 'clamav',
          scan_duration: 0.15,
          file_size: 2048
        )
        
        expect(result.clean?).to be true
        expect(result.infected?).to be false
        expect(result.virus_name).to be_nil
        expect(result.scanner).to eq('clamav')
        expect(result.scan_duration).to eq(0.15)
        expect(result.file_size).to eq(2048)
      end
    end
    
    describe '#to_h' do
      it 'returns hash representation for storage' do
        result = VirusScannerService::ScanResult.new(
          clean: false,
          virus_name: 'EICAR-Test-File',
          scanner: 'clamav',
          scan_duration: 0.23,
          file_size: 68
        )
        
        hash = result.to_h
        expect(hash[:clean]).to eq(false)
        expect(hash[:infected]).to eq(true)
        expect(hash[:virus_name]).to eq('EICAR-Test-File')
        expect(hash[:scanner]).to eq('clamav')
        expect(hash[:scan_duration]).to eq(0.23)
        expect(hash[:file_size]).to eq(68)
        expect(hash[:scanned_at]).to be_within(1.second).of(Time.current)
      end
    end
  end
  
  describe 'Error classes' do
    it 'defines custom error hierarchy' do
      expect(VirusScannerService::Error).to be < StandardError
      expect(VirusScannerService::InvalidFileError).to be < VirusScannerService::Error
      expect(VirusScannerService::InvalidStatusError).to be < VirusScannerService::Error
      expect(VirusScannerService::FileNotFoundError).to be < VirusScannerService::Error
      expect(VirusScannerService::ScannerUnavailableError).to be < VirusScannerService::Error
      expect(VirusScannerService::ScanTimeoutError).to be < VirusScannerService::Error
    end
  end
  
  describe 'Configuration' do
    it 'has configurable timeout' do
      expect(VirusScannerService::SCAN_TIMEOUT).to eq(30.seconds)
    end
    
    it 'has configurable ClamAV connection details' do
      expect(VirusScannerService::CLAMAV_HOST).to eq('localhost')
      expect(VirusScannerService::CLAMAV_PORT).to eq(3310)
    end
  end
end
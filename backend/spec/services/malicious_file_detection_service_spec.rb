# spec/services/malicious_file_detection_service_spec.rb
require 'rails_helper'

RSpec.describe MaliciousFileDetectionService, type: :service do
  let(:service) { described_class.new }
  
  describe '#scan_file' do
    context 'with safe files' do
      it 'allows common audio files' do
        safe_files = [
          { filename: 'song.mp3', content_type: 'audio/mpeg' },
          { filename: 'track.wav', content_type: 'audio/wav' },
          { filename: 'beat.aiff', content_type: 'audio/aiff' },
          { filename: 'master.flac', content_type: 'audio/flac' },
          { filename: 'vocal.m4a', content_type: 'audio/mp4' }
        ]
        
        safe_files.each do |file_info|
          result = service.scan_file(file_info[:filename], file_info[:content_type])
          expect(result.safe?).to be true
          expect(result.risk_level).to eq(:low)
          expect(result.threats).to be_empty
        end
      end
      
      it 'allows project files' do
        project_files = [
          { filename: 'song.logicx', content_type: 'application/octet-stream' },
          { filename: 'track.als', content_type: 'application/octet-stream' },
          { filename: 'beat.flp', content_type: 'application/octet-stream' },
          { filename: 'master.ptx', content_type: 'application/octet-stream' }
        ]
        
        project_files.each do |file_info|
          result = service.scan_file(file_info[:filename], file_info[:content_type])
          expect(result.safe?).to be true
          expect(result.risk_level).to eq(:low)
        end
      end
      
      it 'allows document files' do
        document_files = [
          { filename: 'lyrics.txt', content_type: 'text/plain' },
          { filename: 'contract.pdf', content_type: 'application/pdf' },
          { filename: 'notes.docx', content_type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' },
          { filename: 'data.xlsx', content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' }
        ]
        
        document_files.each do |file_info|
          result = service.scan_file(file_info[:filename], file_info[:content_type])
          expect(result.safe?).to be true
          expect(result.risk_level).to eq(:low)
        end
      end
      
      it 'allows plugin files that musicians might need' do
        plugin_files = [
          { filename: 'reverb.dll', content_type: 'application/octet-stream' },
          { filename: 'compressor.vst', content_type: 'application/octet-stream' },
          { filename: 'delay.component', content_type: 'application/octet-stream' },
          { filename: 'synth.aax', content_type: 'application/octet-stream' }
        ]
        
        plugin_files.each do |file_info|
          result = service.scan_file(file_info[:filename], file_info[:content_type])
          expect(result.safe?).to be true
          expect(result.risk_level).to eq(:medium) # Plugins are medium risk but allowed
          expect(result.requires_verification?).to be true
        end
      end
      
      it 'allows legitimate executables with warning' do
        executable_files = [
          { filename: 'installer.exe', content_type: 'application/octet-stream' },
          { filename: 'setup.msi', content_type: 'application/x-msi' },
          { filename: 'plugin_installer.pkg', content_type: 'application/octet-stream' }
        ]
        
        executable_files.each do |file_info|
          result = service.scan_file(file_info[:filename], file_info[:content_type])
          expect(result.safe?).to be true
          expect(result.risk_level).to eq(:medium)
          expect(result.requires_verification?).to be true
          expect(result.warnings).to include('Executable file detected')
        end
      end
    end
    
    context 'with suspicious files' do
      it 'flags script files as high risk' do
        script_files = [
          { filename: 'malware.bat', content_type: 'text/plain' },
          { filename: 'virus.cmd', content_type: 'text/plain' },
          { filename: 'trojan.ps1', content_type: 'text/plain' },
          { filename: 'backdoor.vbs', content_type: 'text/plain' },
          { filename: 'keylogger.js', content_type: 'application/javascript' }
        ]
        
        script_files.each do |file_info|
          result = service.scan_file(file_info[:filename], file_info[:content_type])
          expect(result.safe?).to be false
          expect(result.risk_level).to eq(:high)
          expect(result.threats).to include('Script file with potential for malicious execution')
        end
      end
      
      it 'flags executable files with suspicious names' do
        suspicious_files = [
          { filename: 'virus.exe', content_type: 'application/octet-stream' },
          { filename: 'malware.scr', content_type: 'application/octet-stream' },
          { filename: 'trojan.pif', content_type: 'application/octet-stream' },
          { filename: 'keylogger.com', content_type: 'application/octet-stream' }
        ]
        
        suspicious_files.each do |file_info|
          result = service.scan_file(file_info[:filename], file_info[:content_type])
          expect(result.safe?).to be false
          expect(result.risk_level).to eq(:high)
          expect(result.threats).to include('Executable with suspicious naming pattern')
        end
      end
      
      it 'flags files with multiple extensions' do
        double_extension_files = [
          { filename: 'song.mp3.exe', content_type: 'application/octet-stream' },
          { filename: 'photo.jpg.scr', content_type: 'application/octet-stream' },
          { filename: 'document.pdf.bat', content_type: 'text/plain' }
        ]
        
        double_extension_files.each do |file_info|
          result = service.scan_file(file_info[:filename], file_info[:content_type])
          expect(result.safe?).to be false
          expect(result.risk_level).to eq(:high)
          expect(result.threats).to include('Multiple file extensions detected')
        end
      end
    end
    
    context 'with blocked file types' do
      it 'blocks dangerous file types completely' do
        blocked_files = [
          { filename: 'malware.scr', content_type: 'application/octet-stream' },
          { filename: 'virus.pif', content_type: 'application/octet-stream' },
          { filename: 'trojan.com', content_type: 'application/octet-stream' }
        ]
        
        blocked_files.each do |file_info|
          result = service.scan_file(file_info[:filename], file_info[:content_type])
          expect(result.safe?).to be false
          expect(result.blocked?).to be true
          expect(result.risk_level).to eq(:critical)
        end
      end
    end
    
    context 'with edge cases' do
      it 'handles nil or empty filenames gracefully' do
        [nil, '', '   '].each do |invalid_filename|
          result = service.scan_file(invalid_filename, 'text/plain')
          expect(result.safe?).to be false
          expect(result.risk_level).to eq(:high)
          expect(result.threats).to include('Invalid or missing filename')
        end
      end
      
      it 'handles suspicious MIME type mismatches' do
        # Audio file claiming to be executable
        result = service.scan_file('song.mp3', 'application/x-executable')
        expect(result.safe?).to be false
        expect(result.risk_level).to eq(:high)
        expect(result.threats).to include('MIME type mismatch detected')
      end
      
      it 'handles very long filenames' do
        long_filename = 'a' * 500 + '.mp3'
        result = service.scan_file(long_filename, 'audio/mpeg')
        expect(result.safe?).to be false
        expect(result.threats).to include('Filename exceeds safe length limits')
      end
      
      it 'detects path traversal attempts' do
        path_traversal_files = [
          '../../../etc/passwd',
          '..\\..\\windows\\system32\\virus.exe',
          'normal/../../../malicious.exe'
        ]
        
        path_traversal_files.each do |filename|
          result = service.scan_file(filename, 'application/octet-stream')
          expect(result.safe?).to be false
          expect(result.threats).to include('Path traversal attempt detected')
        end
      end
    end
  end
  
  describe '#scan_content' do
    context 'when content scanning is enabled' do
      it 'detects suspicious content patterns' do
        # Simulated suspicious content (would be actual file content in real implementation)
        suspicious_content = "MZ\x90\x00\x03\x00\x00\x00" # PE header
        
        result = service.scan_content(suspicious_content, 'text.txt', 'text/plain')
        expect(result.safe?).to be false
        expect(result.threats).to include('Suspicious binary content in text file')
      end
      
      it 'allows legitimate binary content in appropriate files' do
        # Valid MP3 header
        mp3_content = "ID3\x03\x00\x00\x00"
        
        result = service.scan_content(mp3_content, 'song.mp3', 'audio/mpeg')
        expect(result.safe?).to be true
      end
    end
  end
  
  describe 'integration with scan result' do
    it 'returns consistent scan result objects' do
      result = service.scan_file('song.mp3', 'audio/mpeg')
      
      expect(result).to respond_to(:safe?)
      expect(result).to respond_to(:blocked?)
      expect(result).to respond_to(:requires_verification?)
      expect(result).to respond_to(:risk_level)
      expect(result).to respond_to(:threats)
      expect(result).to respond_to(:warnings)
      expect(result).to respond_to(:details)
    end
  end
end
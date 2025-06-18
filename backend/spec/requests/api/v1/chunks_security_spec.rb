# spec/requests/api/v1/chunks_security_spec.rb
require 'rails_helper'

RSpec.describe "Chunks Security Integration", type: :request do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user: user) }
  let(:container) { create(:container, workspace: workspace, name: "Audio Files") }
  let(:token) { generate_token_for_user(user) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  describe "POST /api/v1/uploads/:id/chunks/:chunk_number with security scanning" do
    context "with safe files" do
      it "allows safe audio files to upload normally" do
        upload_session = create(:upload_session,
          workspace: workspace,
          user: user,
          filename: "song.mp3",
          total_size: 1024,
          chunks_count: 1,
          status: 'pending'
        )

        chunk_file = create_test_file("test audio content")

        post "/api/v1/uploads/#{upload_session.id}/chunks/1",
             params: { file: chunk_file, checksum: calculate_md5(chunk_file) },
             headers: headers

        expect(response).to have_http_status(:created)
        
        json_response = JSON.parse(response.body)
        expect(json_response['chunk']['status']).to eq('completed')
        expect(json_response).not_to have_key('security_warning')
      end

      it "allows project files to upload normally" do
        upload_session = create(:upload_session,
          workspace: workspace,
          user: user,
          filename: "project.logicx",
          total_size: 1024,
          chunks_count: 1,
          status: 'pending'
        )

        chunk_file = create_test_file("Logic Pro project data")

        post "/api/v1/uploads/#{upload_session.id}/chunks/1",
             params: { file: chunk_file, checksum: calculate_md5(chunk_file) },
             headers: headers

        expect(response).to have_http_status(:created)
        
        json_response = JSON.parse(response.body)
        expect(json_response['chunk']['status']).to eq('completed')
      end
    end

    context "with medium risk files (plugins/executables)" do
      it "allows plugin files with security warnings" do
        upload_session = create(:upload_session,
          workspace: workspace,
          user: user,
          filename: "reverb.vst",
          total_size: 1024,
          chunks_count: 1,
          status: 'pending'
        )

        chunk_file = create_test_file("VST plugin binary data")

        post "/api/v1/uploads/#{upload_session.id}/chunks/1",
             params: { file: chunk_file, checksum: calculate_md5(chunk_file) },
             headers: headers

        expect(response).to have_http_status(:created)
        
        json_response = JSON.parse(response.body)
        expect(json_response['chunk']['status']).to eq('completed')
        expect(json_response['security_warning']).to be_present
        expect(json_response['security_warning']['risk_level']).to eq('medium')
        expect(json_response['security_warning']['warnings']).to include('Executable file detected')
        expect(json_response['security_warning']['requires_verification']).to be true
      end

      it "allows legitimate executables with warnings" do
        upload_session = create(:upload_session,
          workspace: workspace,
          user: user,
          filename: "plugin_installer.exe",
          total_size: 1024,
          chunks_count: 1,
          status: 'pending'
        )

        chunk_file = create_test_file("Installer executable data")

        post "/api/v1/uploads/#{upload_session.id}/chunks/1",
             params: { file: chunk_file, checksum: calculate_md5(chunk_file) },
             headers: headers

        expect(response).to have_http_status(:created)
        
        json_response = JSON.parse(response.body)
        expect(json_response['security_warning']['risk_level']).to eq('medium')
      end
    end

    context "with high risk files (suspicious but allowed)" do
      it "allows suspicious files with strong warnings" do
        upload_session = create(:upload_session,
          workspace: workspace,
          user: user,
          filename: "suspicious_script.bat",
          total_size: 1024,
          chunks_count: 1,
          status: 'pending'
        )

        chunk_file = create_test_file("@echo off\necho hello")

        post "/api/v1/uploads/#{upload_session.id}/chunks/1",
             params: { file: chunk_file, checksum: calculate_md5(chunk_file) },
             headers: headers

        expect(response).to have_http_status(:created)
        
        json_response = JSON.parse(response.body)
        expect(json_response['chunk']['status']).to eq('completed')
        expect(json_response['security_warning']['risk_level']).to eq('high')
        expect(json_response['security_warning']['threats']).to include('Script file with potential for malicious execution')
        expect(json_response['security_warning']['safe']).to be false
      end

      it "flags files with suspicious names" do
        upload_session = create(:upload_session,
          workspace: workspace,
          user: user,
          filename: "virus.exe",
          total_size: 1024,
          chunks_count: 1,
          status: 'pending'
        )

        chunk_file = create_test_file("Executable content")

        post "/api/v1/uploads/#{upload_session.id}/chunks/1",
             params: { file: chunk_file, checksum: calculate_md5(chunk_file) },
             headers: headers

        expect(response).to have_http_status(:created)
        
        json_response = JSON.parse(response.body)
        expect(json_response['security_warning']['risk_level']).to eq('high')
        expect(json_response['security_warning']['threats']).to include('Executable with suspicious naming pattern')
      end

      it "flags files with multiple extensions" do
        upload_session = create(:upload_session,
          workspace: workspace,
          user: user,
          filename: "song.mp3.exe",
          total_size: 1024,
          chunks_count: 1,
          status: 'pending'
        )

        chunk_file = create_test_file("Suspicious content")

        post "/api/v1/uploads/#{upload_session.id}/chunks/1",
             params: { file: chunk_file, checksum: calculate_md5(chunk_file) },
             headers: headers

        expect(response).to have_http_status(:created)
        
        json_response = JSON.parse(response.body)
        expect(json_response['security_warning']['threats']).to include('Multiple file extensions detected')
      end
    end

    context "with blocked files (critical risk)" do
      it "rejects screensaver files completely" do
        upload_session = create(:upload_session,
          workspace: workspace,
          user: user,
          filename: "malware.scr",
          total_size: 1024,
          chunks_count: 1,
          status: 'pending'
        )

        chunk_file = create_test_file("Malicious screensaver")

        post "/api/v1/uploads/#{upload_session.id}/chunks/1",
             params: { file: chunk_file, checksum: calculate_md5(chunk_file) },
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('File type is not allowed for security reasons')
        expect(json_response['security_details']['risk_level']).to eq('critical')
        expect(json_response['security_details']['blocked']).to be true
      end

      it "rejects PIF files completely" do
        upload_session = create(:upload_session,
          workspace: workspace,
          user: user,
          filename: "virus.pif",
          total_size: 1024,
          chunks_count: 1,
          status: 'pending'
        )

        chunk_file = create_test_file("Malicious PIF file")

        post "/api/v1/uploads/#{upload_session.id}/chunks/1",
             params: { file: chunk_file, checksum: calculate_md5(chunk_file) },
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['error']).to include('File type is not allowed')
      end

      it "rejects COM files completely" do
        upload_session = create(:upload_session,
          workspace: workspace,
          user: user,
          filename: "trojan.com",
          total_size: 1024,
          chunks_count: 1,
          status: 'pending'
        )

        chunk_file = create_test_file("DOS executable")

        post "/api/v1/uploads/#{upload_session.id}/chunks/1",
             params: { file: chunk_file, checksum: calculate_md5(chunk_file) },
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "with content analysis" do
      it "detects suspicious binary content in text files" do
        upload_session = create(:upload_session,
          workspace: workspace,
          user: user,
          filename: "document.txt",
          total_size: 1024,
          chunks_count: 1,
          status: 'pending'
        )

        # Create file with PE header (Windows executable signature)
        suspicious_content = "MZ\x90\x00\x03\x00\x00\x00" + "text content"
        chunk_file = create_test_file(suspicious_content)

        post "/api/v1/uploads/#{upload_session.id}/chunks/1",
             params: { file: chunk_file, checksum: calculate_md5(chunk_file) },
             headers: headers

        expect(response).to have_http_status(:created)
        
        json_response = JSON.parse(response.body)
        expect(json_response['security_warning']['threats']).to include('Suspicious binary content in text file')
      end
    end

    context "error handling" do
      it "continues upload if security scanning fails" do
        upload_session = create(:upload_session,
          workspace: workspace,
          user: user,
          filename: "normal_file.mp3",
          total_size: 1024,
          chunks_count: 1,
          status: 'pending'
        )

        chunk_file = create_test_file("audio content")

        # Mock the security service to raise an error
        allow_any_instance_of(MaliciousFileDetectionService).to receive(:scan_content).and_raise(StandardError, "Service error")

        post "/api/v1/uploads/#{upload_session.id}/chunks/1",
             params: { file: chunk_file, checksum: calculate_md5(chunk_file) },
             headers: headers

        expect(response).to have_http_status(:created)
        
        json_response = JSON.parse(response.body)
        expect(json_response['chunk']['status']).to eq('completed')
        expect(json_response['security_warning']['warnings']).to include('Security scan failed - file uploaded without verification')
      end
    end
  end

  private

  def create_test_file(content)
    temp_file = Tempfile.new(['test_chunk', '.bin'])
    temp_file.binmode
    temp_file.write(content)
    temp_file.rewind
    Rack::Test::UploadedFile.new(temp_file.path, 'application/octet-stream')
  end

  def calculate_md5(file)
    file.rewind
    checksum = Digest::MD5.hexdigest(file.read)
    file.rewind
    checksum
  end
end
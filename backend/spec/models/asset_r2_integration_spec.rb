# spec/models/asset_r2_integration_spec.rb
require 'rails_helper'

RSpec.describe Asset, type: :model do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user: user) }
  let(:container) { create(:container, workspace: workspace) }

  describe 'R2 File Integration (Development Environment)' do
    before(:all) do
      puts "\n🧪 Testing R2 Integration in #{Rails.env} environment"
      puts "📤 Storage Service: #{ActiveStorage::Blob.service.class.name}"
      if ActiveStorage::Blob.service.respond_to?(:bucket)
        puts "🪣 R2 Bucket: #{ActiveStorage::Blob.service.bucket.name}"
      end
    end

    context 'when R2 is configured' do
      before do
        skip 'R2 not configured' unless r2_configured?
      end

      describe 'file attachment' do
        let(:test_file_content) { "Test audio content for WubHub\nUploaded at: #{Time.current}" }
        let(:temp_file) do
          file = Tempfile.new(['test_audio', '.txt'])
          file.write(test_file_content)
          file.rewind
          file
        end

        after do
          temp_file.close
          temp_file.unlink
        end

        it 'successfully attaches a file to R2' do
          asset = create(:asset,
            filename: 'test_song.txt',
            workspace: workspace,
            container: container,
            user: user
          )

          asset.file_blob.attach(
            io: temp_file,
            filename: 'test_song.txt',
            content_type: 'text/plain'
          )

          expect(asset.file_blob).to be_attached
          expect(asset.file_blob.filename.to_s).to eq('test_song.txt')
          expect(asset.file_blob.content_type).to eq('text/plain')
          # In development, expect development_r2 service
          expect(asset.file_blob.service_name).to eq('development_r2')
        end

    it 'extracts file metadata correctly' do
      asset = create(:asset,
        filename: 'metadata_test.txt',
        workspace: workspace,
        user: user
      )

      asset.file_blob.attach(
        io: temp_file,
        filename: 'metadata_test.txt',
        content_type: 'text/plain'
      )

      # Extract metadata
      asset.extract_file_metadata!

      expect(asset.file_size).to eq(asset.file_blob.byte_size)
      expect(asset.content_type).to eq('text/plain')
    end

    it 'generates working download URLs' do
      asset = create(:asset,
        filename: 'download_test.txt',
        workspace: workspace,
        user: user
      )

      asset.file_blob.attach(
        io: temp_file,
        filename: 'download_test.txt',
        content_type: 'text/plain'
      )

      download_url = asset.download_url
      expect(download_url).to be_present
      expect(download_url).to match(/https?:\/\//)
    end

    it 'can download uploaded files with correct content' do
      asset = create(:asset,
        filename: 'content_test.txt',
        workspace: workspace,
        user: user
      )

      asset.file_blob.attach(
        io: temp_file,
        filename: 'content_test.txt',
        content_type: 'text/plain'
      )

      downloaded_content = asset.file_blob.download
      expect(downloaded_content).to eq(test_file_content)
    end
  end

  describe 'Multiple File Types Support' do
    let(:audio_file) do
      file = Tempfile.new(['test_audio', '.mp3'])
      file.write('fake mp3 content for testing')
      file.rewind
      file
    end

    let(:image_file) do
      file = Tempfile.new(['test_image', '.jpg'])
      file.write('fake jpg content for testing')
      file.rewind
      file
    end

    after do
      audio_file.close
      audio_file.unlink
      image_file.close
      image_file.unlink
    end

    it 'handles audio file uploads' do
      asset = create(:asset,
        filename: 'song.mp3',
        workspace: workspace,
        user: user
      )

      asset.file_blob.attach(
        io: audio_file,
        filename: 'song.mp3',
        content_type: 'audio/mpeg'
      )

      expect(asset.file_blob).to be_attached
      expect(asset.file_type).to eq('audio')
    end

    it 'handles image file uploads' do
      asset = create(:asset,
        filename: 'cover.jpg',
        workspace: workspace,
        user: user
      )

      asset.file_blob.attach(
        io: image_file,
        filename: 'cover.jpg',
        content_type: 'image/jpeg'
      )

      expect(asset.file_blob).to be_attached
      expect(asset.file_type).to eq('image')
    end
  end

  describe 'R2 Service Connectivity' do
    it 'can connect to R2 and list buckets' do
      s3_client = Aws::S3::Client.new(
        access_key_id: ENV['CLOUDFLARE_R2_ACCESS_KEY_ID'],
        secret_access_key: ENV['CLOUDFLARE_R2_SECRET_ACCESS_KEY'],
        region: 'auto',
        endpoint: ENV['CLOUDFLARE_R2_ENDPOINT'],
        force_path_style: true
      )

      response = s3_client.list_buckets
      bucket_names = response.buckets.map(&:name)
      
      expect(bucket_names).to include(ENV['CLOUDFLARE_R2_BUCKET'])
    end

    it 'can perform direct S3 operations on R2' do
      s3_client = Aws::S3::Client.new(
        access_key_id: ENV['CLOUDFLARE_R2_ACCESS_KEY_ID'],
        secret_access_key: ENV['CLOUDFLARE_R2_SECRET_ACCESS_KEY'],
        region: 'auto',
        endpoint: ENV['CLOUDFLARE_R2_ENDPOINT'],
        force_path_style: true
      )

      test_key = "test/rspec_direct_test_#{Time.current.to_i}.txt"
      test_content = "Direct R2 test from RSpec"

      # Upload
      s3_client.put_object(
        bucket: ENV['CLOUDFLARE_R2_BUCKET'],
        key: test_key,
        body: test_content,
        content_type: 'text/plain'
      )

      # Download
      response = s3_client.get_object(
        bucket: ENV['CLOUDFLARE_R2_BUCKET'],
        key: test_key
      )

      downloaded_content = response.body.read
      expect(downloaded_content).to eq(test_content)

      # Cleanup
      s3_client.delete_object(
        bucket: ENV['CLOUDFLARE_R2_BUCKET'],
        key: test_key
      )
    end
  end

  private

  def r2_credentials_available?
    required_vars = %w[
      CLOUDFLARE_R2_ACCESS_KEY_ID
      CLOUDFLARE_R2_SECRET_ACCESS_KEY
      CLOUDFLARE_R2_BUCKET
      CLOUDFLARE_R2_ENDPOINT
    ]
    
    required_vars.all? { |var| ENV[var].present? }
  end

  def skip_r2_tests
    skip "R2 credentials not available. Set CLOUDFLARE_R2_* environment variables to run R2 integration tests."
  end
end
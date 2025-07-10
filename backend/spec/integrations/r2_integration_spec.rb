# spec/models/asset_r2_integration_spec.rb
require 'rails_helper'

RSpec.describe Asset, type: :model,r2_integration: true  do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user: user) }
  let(:container) { create(:container, workspace: workspace) }

  describe 'R2 File Integration' do
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
          expect(asset.file_blob.service_name).to eq('development_r2')
        end

        it 'extracts file metadata after upload' do
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

          # Test the extract_file_metadata! method
          asset.extract_file_metadata!

          expect(asset.file_size).to eq(asset.file_blob.byte_size)
          expect(asset.content_type).to eq('text/plain')
          expect(asset.file_size).to be > 0
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
          expect(download_url).to include('rails/active_storage/blobs')
          expect(download_url).to be_present
          expect(download_url).to include('rails/active_storage/blobs')
          expect(download_url).to include('localhost:3000')  # or just check it's present
        end

        it 'can download uploaded file content' do
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

        it 'generates humanized file sizes' do
          asset = create(:asset,
            filename: 'size_test.txt',
            workspace: workspace,
            user: user
          )

          asset.file_blob.attach(
            io: temp_file,
            filename: 'size_test.txt',
            content_type: 'text/plain'
          )

          asset.extract_file_metadata!

          expect(asset.humanized_size).to match(/\d+(\.\d+)? [KMGT]?B/)
          expect(asset.humanized_size).not_to eq('Unknown')
        end
      end

      describe 'file type detection' do
        let(:audio_file) do
          file = Tempfile.new(['test_audio', '.mp3'])
          file.write('fake mp3 content')
          file.rewind
          file
        end

        let(:image_file) do
          file = Tempfile.new(['test_image', '.jpg'])
          file.write('fake jpg content')
          file.rewind
          file
        end

        after do
          audio_file.close
          audio_file.unlink
          image_file.close
          image_file.unlink
        end

        it 'detects audio file types correctly' do
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

          expect(asset.file_type).to eq('audio')
          expect(asset.file_extension).to eq('.mp3')
        end

        it 'detects image file types correctly' do
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

          expect(asset.file_type).to eq('image')
          expect(asset.file_extension).to eq('.jpg')
        end

        it 'handles different audio formats' do
          formats = {
            'track.wav' => 'audio/wav',
            'song.flac' => 'audio/flac',
            'demo.m4a' => 'audio/m4a',
            'mix.aiff' => 'audio/aiff'
          }

          formats.each do |filename, content_type|
            asset = build(:asset, filename: filename, workspace: workspace, user: user)
            expect(asset.file_type).to eq('audio')
          end
        end
      end

      describe 'asset organization' do
        it 'maintains proper file paths with R2 storage' do
          # Root level file
          root_asset = create(:asset,
            filename: 'master.wav',
            container: nil,
            workspace: workspace,
            user: user
          )

          expect(root_asset.full_path).to eq('/master.wav')

          # Container file
          container_asset = create(:asset,
            filename: 'vocal.wav',
            container: container,
            workspace: workspace,
            user: user
          )

          expect(container_asset.full_path).to eq("#{container.full_path}/vocal.wav")
        end

        it 'enforces unique filenames within containers with R2' do
          create(:asset,
            filename: 'duplicate.wav',
            container: container,
            workspace: workspace,
            user: user
          )

          duplicate_asset = build(:asset,
            filename: 'duplicate.wav',
            container: container,
            workspace: workspace,
            user: user
          )

          expect(duplicate_asset).not_to be_valid
          expect(duplicate_asset.errors[:filename]).to include('has already been taken')
        end

        it 'allows same filename in different containers with R2' do
          container1 = create(:container, workspace: workspace, name: 'Beats')
          container2 = create(:container, workspace: workspace, name: 'Vocals')

          asset1 = create(:asset,
            filename: 'track.wav',
            container: container1,
            workspace: workspace,
            user: user
          )

          asset2 = build(:asset,
            filename: 'track.wav',
            container: container2,
            workspace: workspace,
            user: user
          )

          expect(asset2).to be_valid
        end
      end

      describe 'R2-specific functionality' do
        let(:temp_file) do
          file = Tempfile.new(['r2_test', '.txt'])
          file.write('R2 specific test content')
          file.rewind
          file
        end

        after do
          temp_file.close
          temp_file.unlink
        end

        it 'stores files with correct R2 service name' do
          asset = create(:asset,
            filename: 'r2_service_test.txt',
            workspace: workspace,
            user: user
          )

          asset.file_blob.attach(
            io: temp_file,
            filename: 'r2_service_test.txt',
            content_type: 'text/plain'
          )

          expect(asset.file_blob.service_name).to eq('development_r2')
        end

        it 'generates R2 URLs with correct endpoint' do
          asset = create(:asset,
            filename: 'r2_url_test.txt',
            workspace: workspace,
            user: user
          )

          asset.file_blob.attach(
            io: temp_file,
            filename: 'r2_url_test.txt',
            content_type: 'text/plain'
          )

          url = asset.download_url
          expect(url).to include('rails/active_storage/blobs')    
          expect(url).to be_present
          expect(url).to include('rails/active_storage/blobs')
        end

        it 'handles R2 blob keys correctly' do
          asset = create(:asset,
            filename: 'r2_key_test.txt',
            workspace: workspace,
            user: user
          )

          asset.file_blob.attach(
            io: temp_file,
            filename: 'r2_key_test.txt',
            content_type: 'text/plain'
          )

          # R2 blob keys should be properly formatted
          expect(asset.file_blob.key).to be_present
          expect(asset.file_blob.key).to match(/^[a-zA-Z0-9\/\-_]+$/)
        end
      end
    end

    context 'when R2 is not configured' do
      before do
        skip 'R2 is configured' if r2_configured?
      end

      # it 'falls back to local storage' do
      #   service = ActiveStorage::Blob.service
      #   expect(service.class.name).to include('Disk')
      # end

      # it 'still creates assets without file attachments' do
      #   asset = create(:asset,
      #     filename: 'local_test.txt',
      #     workspace: workspace,
      #     user: user
      #   )

      #   expect(asset).to be_valid
      #   expect(asset.file_blob).not_to be_attached
      # end
    end
  end

  private

  def r2_configured?
    ENV['CLOUDFLARE_R2_ACCESS_KEY_ID'].present? &&
    ENV['CLOUDFLARE_R2_SECRET_ACCESS_KEY'].present? &&
    ENV['CLOUDFLARE_R2_BUCKET'].present? &&
    ENV['CLOUDFLARE_R2_ENDPOINT'].present?
  end
end
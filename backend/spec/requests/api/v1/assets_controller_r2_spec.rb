require 'rails_helper'

RSpec.describe Api::V1::AssetsController, type: :controller, r2_integration: true do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace, user: user) }
  let(:container) { create(:container, workspace: workspace) }

  before do
    # Mock authentication
    allow(controller).to receive(:authenticate_user!).and_return(true)
    allow(controller).to receive(:current_user).and_return(user)
  end

  describe 'R2 File Upload Integration' do
    context 'when R2 is configured' do
      before do
        skip 'R2 not configured' unless r2_configured?
      end

      describe 'POST #create with file upload' do
        let(:test_file) do
          Tempfile.new(['controller_test', '.mp3']).tap do |file|
            file.write('fake mp3 content for controller test')
            file.rewind
          end
        end

        let(:uploaded_file) do
          Rack::Test::UploadedFile.new(test_file.path, 'audio/mpeg', original_filename: 'test_song.mp3')
        end

        after do
          test_file.close
          test_file.unlink
        end

        it 'creates asset with file upload to R2' do
          expect {
            post :create, params: {
              workspace_id: workspace.id,
              asset: {
                filename: 'test_song.mp3',
                container_id: container.id
              },
              file: uploaded_file
            }
          }.to change(Asset, :count).by(1)

          expect(response).to have_http_status(:created)
          
          asset = Asset.last
          expect(asset.filename).to eq('test_song.mp3')
          expect(asset.file_blob).to be_attached
          expect(asset.file_blob.content_type).to eq('audio/mpeg')
          expect(asset.file_blob.service_name).to eq('development_r2')
        end

        it 'extracts file metadata after upload' do
          post :create, params: {
            workspace_id: workspace.id,
            asset: {
              filename: 'metadata_test.mp3',
              container_id: container.id
            },
            file: uploaded_file
          }

          asset = Asset.last
          expect(asset.file_size).to be > 0
          expect(asset.content_type).to eq('audio/mpeg')
        end

        it 'returns asset with serialized data including R2 info' do
          post :create, params: {
            workspace_id: workspace.id,
            asset: {
              filename: 'serializer_test.mp3'
            },
            file: uploaded_file
          }

          expect(response).to have_http_status(:created)
          json_response = JSON.parse(response.body)
          
          expect(json_response['filename']).to eq('serializer_test.mp3')
          expect(json_response['file_size']).to be_present
          expect(json_response['content_type']).to eq('audio/mpeg')
        end

        it 'handles upload errors gracefully' do
          # Create an asset that would cause a validation error
          create(:asset, 
            filename: 'duplicate.mp3',
            workspace: workspace,
            container: container,
            user: user
          )

          post :create, params: {
            workspace_id: workspace.id,
            asset: {
              filename: 'duplicate.mp3',
              container_id: container.id
            },
            file: uploaded_file
          }

          expect(response).to have_http_status(:unprocessable_entity)
          json_response = JSON.parse(response.body)
          expect(json_response['errors']).to include('Filename has already been taken')
        end

        it 'creates asset without container (workspace root)' do
          post :create, params: {
            workspace_id: workspace.id,
            asset: {
              filename: 'root_file.mp3'
            },
            file: uploaded_file
          }

          expect(response).to have_http_status(:created)
          
          asset = Asset.last
          expect(asset.container).to be_nil
          expect(asset.full_path).to eq('/root_file.mp3')
          expect(asset.file_blob).to be_attached
        end
      end

      describe 'GET #download' do
        let(:asset) do
          create(:asset,
            filename: 'download_test.mp3',
            workspace: workspace,
            user: user
          )
        end

        let(:test_file) do
          Tempfile.new(['download_test', '.mp3']).tap do |file|
            file.write('test download content')
            file.rewind
          end
        end

        before do
          asset.file_blob.attach(
            io: test_file,
            filename: 'download_test.mp3',
            content_type: 'audio/mpeg'
          )
        end

        after do
          test_file.close
          test_file.unlink
        end

        it 'redirects to R2 download URL' do
          get :download, params: { id: asset.id }

          expect(response).to have_http_status(:found)
          expect(response.location).to include('rails/active_storage/blobs')
          expect(response.location).to include('rails/active_storage/blobs')
        end

        it 'returns 404 for asset without file' do
          asset_without_file = create(:asset,
            filename: 'no_file.mp3',
            workspace: workspace,
            user: user
          )

          get :download, params: { id: asset_without_file.id }

          expect(response).to have_http_status(:not_found)
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to eq('No file attached to this asset')
        end
      end

      describe 'GET #index with R2 files' do
        before do
          # Clean up assets for this specific workspace only (better isolation)
          workspace.assets.destroy_all
          
          # Create assets with R2 files
          3.times do |i|
            asset = create(:asset,
              filename: "song_#{i}.mp3",
              workspace: workspace,
              container: container,
              user: user
            )

            test_file = Tempfile.new(["song_#{i}", '.mp3'])
            test_file.write("content for song #{i}")
            test_file.rewind

            asset.file_blob.attach(
              io: test_file,
              filename: "song_#{i}.mp3",
              content_type: 'audio/mpeg'
            )

            asset.extract_file_metadata!
            
            test_file.close
            test_file.unlink
          end
        end

        it 'lists assets with R2 file information' do
          get :index, params: { workspace_id: workspace.id }

          expect(response).to have_http_status(:ok)
          json_response = JSON.parse(response.body)
          
          expect(json_response.length).to eq(3)
          
          json_response.each do |asset_data|
            expect(asset_data['filename']).to match(/song_\d\.mp3/)
            expect(asset_data['file_size']).to be > 0
            expect(asset_data['content_type']).to eq('audio/mpeg')
          end
        end

        it 'filters by container' do
          # Create asset in different container
          other_container = create(:container, workspace: workspace, name: 'Other')
          other_asset = create(:asset,
            filename: 'other_song.mp3',
            workspace: workspace,
            container: other_container,
            user: user
          )

          get :index, params: { 
            workspace_id: workspace.id,
            container_id: container.id
          }

          expect(response).to have_http_status(:ok)
          json_response = JSON.parse(response.body)
          
          # Should only return assets from the specified container
          expect(json_response.length).to eq(3)
          json_response.each do |asset_data|
            expect(asset_data['filename']).to match(/song_\d\.mp3/)
          end
        end

        it 'filters by content type' do
          # Create an image asset in the same workspace/container
          image_asset = create(:asset,
            filename: 'cover.jpg',
            workspace: workspace,
            container: container,
            user: user,
            content_type: 'image/jpeg'
          )

          # Also add a file attachment to make it realistic
          image_file = Tempfile.new(['cover', '.jpg'])
          image_file.write('fake image content')
          image_file.rewind

          image_asset.file_blob.attach(
            io: image_file,
            filename: 'cover.jpg',
            content_type: 'image/jpeg'
          )
          image_asset.extract_file_metadata!
          
          image_file.close
          image_file.unlink

          get :index, params: { 
            workspace_id: workspace.id,
            content_type: 'audio/mpeg'
          }

          expect(response).to have_http_status(:ok)
          json_response = JSON.parse(response.body)
          
          # Should only return audio files (3 songs, not the image)
          expect(json_response.length).to eq(3)
          json_response.each do |asset_data|
            expect(asset_data['content_type']).to eq('audio/mpeg')
            expect(asset_data['filename']).to match(/song_\d\.mp3/)
          end
        end
      end
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
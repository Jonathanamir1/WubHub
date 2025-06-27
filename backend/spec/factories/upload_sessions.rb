# spec/factories/upload_sessions.rb (UPDATED WITH QUEUE INTEGRATION)
FactoryBot.define do
  factory :upload_session do
    sequence(:filename) { |n| "file_#{n}.mp3" }
    total_size { 10.megabytes }
    chunks_count { 10 }
    status { 'pending' }
    metadata { {} }
    
    # Create user first, then workspace owned by that user
    user
    workspace { association(:workspace, user: user) }
    # container is optional - defaults to nil (workspace root)
    # queue_item is optional - defaults to nil (standalone upload)
    
    trait :in_container do
      association :container
    end
    
    # NEW: Queue-related traits
    trait :queued do
      association :queue_item
      
      # Ensure queue_item belongs to same workspace and user
      after(:build) do |upload_session|
        upload_session.queue_item.workspace = upload_session.workspace
        upload_session.queue_item.user = upload_session.user
      end
    end
    
    trait :standalone do
      queue_item { nil }
    end
    
    trait :in_batch do
      transient do
        batch_id { SecureRandom.uuid }
        batch_size { 5 }
      end
      
      after(:build) do |upload_session, evaluator|
        # Create or find queue_item for this batch
        upload_session.queue_item = build(:queue_item,
          workspace: upload_session.workspace,
          user: upload_session.user,
          batch_id: evaluator.batch_id,
          total_files: evaluator.batch_size,
          draggable_type: 'folder',
          draggable_name: 'Batch Upload'
        )
      end
    end
    
    # Status traits
    trait :uploading do
      status { 'uploading' }
    end
    
    trait :assembling do
      status { 'assembling' }
    end
    
    trait :virus_scanning do
      status { 'virus_scanning' }
    end
    
    trait :finalizing do
      status { 'finalizing' }
    end
    
    trait :completed do
      status { 'completed' }
    end
    
    trait :failed do
      status { 'failed' }
    end
    
    trait :cancelled do
      status { 'cancelled' }
    end
    
    trait :virus_detected do
      status { 'virus_detected' }
    end
    
    # File type traits
    trait :audio_file do
      filename { "#{Faker::Music.album.parameterize}.wav" }
      total_size { 50.megabytes }
      chunks_count { 50 }
    end
    
    trait :logic_project do
      filename { "#{Faker::Music.album.parameterize}.logic" }
      total_size { 500.megabytes }
      chunks_count { 100 }
    end
    
    trait :large_file do
      filename { "#{Faker::Music.album.parameterize}_stems.zip" }
      total_size { 2.gigabytes }
      chunks_count { 200 }
    end
    
    trait :small_file do
      filename { "demo.mp3" }
      total_size { 5.megabytes }
      chunks_count { 5 }
    end
    
    # With specific container (ensures container belongs to same workspace)
    trait :with_container do
      transient do
        container_name { 'Beats' }
      end
      
      after(:build) do |upload_session, evaluator|
        # Create container in the same workspace
        upload_session.container = create(:container, 
          workspace: upload_session.workspace,
          name: evaluator.container_name
        )
      end
    end
    
    # With collaborator access (user doesn't own workspace but has collaborator role)
    trait :as_collaborator do
      transient do
        workspace_owner { create(:user) }
      end
      
      workspace { association(:workspace, user: workspace_owner) }
      
      after(:build) do |upload_session, evaluator|
        # Give the user collaborator role on the workspace
        create(:role, 
          user: upload_session.user, 
          roleable: upload_session.workspace, 
          name: 'collaborator'
        )
      end
    end
    
    # With viewer access (should fail upload permission check)
    trait :as_viewer do
      transient do
        workspace_owner { create(:user) }
      end
      
      workspace { association(:workspace, user: workspace_owner) }
      
      after(:create) do |upload_session, evaluator|
        # Give the user viewer role on the workspace
        create(:role, 
          user: upload_session.user, 
          roleable: upload_session.workspace, 
          name: 'viewer'
        )
      end
    end
    
    # No access (user has no relationship to workspace)
    trait :no_access do
      transient do
        workspace_owner { create(:user) }
      end
      
      workspace { association(:workspace, user: workspace_owner) }
      # user has no role on this workspace
    end
    
    # Expired sessions for cleanup tests
    trait :expired_failed do
      status { 'failed' }
      created_at { 25.hours.ago }
    end
    
    trait :expired_pending do
      status { 'pending' }
      created_at { 2.hours.ago }
    end
    
    # With metadata
    trait :with_metadata do
      metadata do
        {
          original_path: '/Users/artist/Music/Project.logic',
          client_info: { browser: 'Chrome', version: '91.0' },
          upload_source: 'web_interface',
          file_type: 'logic_project',
          estimated_duration: 180.5
        }
      end
    end
    
    # NEW: Queue integration scenarios
    trait :first_in_queue do
      queued
      
      after(:build) do |upload_session|
        upload_session.queue_item.update!(completed_files: 0)
      end
    end
    
    trait :last_in_queue do
      queued
      
      after(:build) do |upload_session|
        upload_session.queue_item.update!(
          completed_files: upload_session.queue_item.total_files - 1
        )
      end
    end
    
    trait :completed_in_queue do
      queued
      
      after(:build) do |upload_session|
        # Ensure queue_item has proper file count
        upload_session.queue_item.update!(total_files: 1, completed_files: 0)
        # Set status to completed
        upload_session.status = 'completed'
      end
      
      after(:create) do |upload_session|
        # Manually trigger the queue notification since we bypassed the state machine
        upload_session.queue_item.mark_file_completed!
      end
    end
    
    trait :failed_in_queue do
      queued
      failed
      
      after(:create) do |upload_session|
        # This will trigger the queue_item update
        upload_session.queue_item.mark_file_failed!
      end
    end
  end
end
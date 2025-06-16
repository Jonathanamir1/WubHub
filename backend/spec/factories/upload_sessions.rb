# spec/factories/upload_sessions.rb
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
    
    trait :in_container do
      association :container
    end
    
    trait :uploading do
      status { 'uploading' }
    end
    
    trait :assembling do
      status { 'assembling' }
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
  end
end
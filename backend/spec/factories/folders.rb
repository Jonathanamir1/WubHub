FactoryBot.define do
  factory :folder do
    sequence(:name) { |n| "Folder #{n}" }
    association :project
    association :user
    
    trait :with_parent do
      association :parent_folder, factory: :folder
    end
    
    trait :with_subfolders do
      after(:create) do |folder|
        create_list(:folder, 2, parent_folder: folder, project: folder.project, user: folder.user)
      end
    end
    
    trait :with_audio_files do
      after(:create) do |folder|
        create_list(:audio_file, 2, folder: folder, project: folder.project, user: folder.user)
      end
    end
  end
end
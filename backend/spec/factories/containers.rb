# spec/factories/containers.rb
FactoryBot.define do
  factory :container do
    sequence(:name) { |n| "Folder #{n}" }
    association :workspace
    
    trait :with_parent do
      association :parent_container, factory: :container
    end
    
    trait :with_children do
      after(:create) do |container|
        create_list(:container, 3, parent_container: container, workspace: container.workspace)
      end
    end
    
    trait :with_files do
      after(:create) do |container|
        user = create(:user)
        create_list(:file, 5, container: container, workspace: container.workspace, user: user)
      end
    end
    
    # Specific folder types for music workflows
    trait :beats_folder do
      name { 'Beats' }
    end
    
    trait :vocals_folder do
      name { 'Vocals' }
    end
    
    trait :stems_folder do
      name { 'Stems' }
    end
    
    trait :projects_folder do
      name { 'Projects' }
    end
  end
end
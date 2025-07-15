# spec/factories/workspaces.rb
FactoryBot.define do
  factory :workspace do
    sequence(:name) { |n| "Workspace #{n}" }
    description { "A test workspace" }
    workspace_type { 'project_based' }  # Default to project_based for tests
    association :user

    # Traits for different workspace types
    trait :project_based do
      workspace_type { 'project_based' }
      name { "My Music Projects" }
      description { "Personal music projects and creative work" }
    end

    trait :client_based do
      workspace_type { 'client_based' }
      name { "Client Work Studio" }
      description { "Professional workspace for client projects" }
    end

    trait :library do
      workspace_type { 'library' }
      name { "Sample Library" }
      description { "Collection of samples, loops, and references" }
    end

    # Keep existing trait for backwards compatibility
    trait :with_projects do
      after(:create) do |workspace|
        create_list(:project, 3, workspace: workspace, user: workspace.user)
      end
    end
  end
end
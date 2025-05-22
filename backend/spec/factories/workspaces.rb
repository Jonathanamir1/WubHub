FactoryBot.define do
  factory :workspace do
    sequence(:name) { |n| "Workspace #{n}" }
    description { "A test workspace" }
    visibility { "private" }
    association :user

    trait :public do
      visibility { "public" }
    end

    trait :with_projects do
      after(:create) do |workspace|
        create_list(:project, 3, workspace: workspace, user: workspace.user)
      end
    end
  end
end
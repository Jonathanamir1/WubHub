FactoryBot.define do
  factory :project do
    sequence(:title) { |n| "Project #{n}" }
    description { "A test project description" }
    association :workspace
    association :user

    trait :with_versions do
      after(:create) do |project|
        create_list(:track_version, 2, project: project, user: project.user)
      end
    end
  end
end
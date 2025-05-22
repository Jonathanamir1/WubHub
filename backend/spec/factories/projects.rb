FactoryBot.define do
  factory :project do
    sequence(:title) { |n| "Project #{n}" }
    description { "A test project description" }
    visibility { "private" }
    association :workspace
    association :user

    trait :public do
      visibility { "public" }
    end

    trait :with_versions do
      after(:create) do |project|
        create_list(:track_version, 2, project: project, user: project.user)
      end
    end
  end
end
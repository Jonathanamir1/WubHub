FactoryBot.define do
  factory :role do
    name { "collaborator" }
    association :user
    association :roleable, factory: :project  # Add this back for default

    trait :owner do
      name { "owner" }
    end

    trait :viewer do
      name { "viewer" }
    end

    trait :workspace_role do
      association :roleable, factory: :workspace
    end

    trait :track_version_role do
      association :roleable, factory: :track_version
    end
  end
end
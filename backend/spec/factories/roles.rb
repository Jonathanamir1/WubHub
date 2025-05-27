FactoryBot.define do
  factory :role do
    name { "collaborator" }
    association :user
    association :roleable, factory: :project

    trait :owner do
      name { "owner" }
    end

    trait :viewer do
      name { "viewer" }
    end

    trait :workspace_role do
      association :roleable, factory: :workspace
    end
  end
end
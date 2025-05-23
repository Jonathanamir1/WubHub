FactoryBot.define do
  factory :role do
    name { "collaborator" }
    association :user

    trait :for_project do
      association :roleable, factory: :project
    end

    trait :for_workspace do
      association :roleable, factory: :workspace
    end

    trait :owner do
      name { "owner" }
    end

    trait :viewer do
      name { "viewer" }
    end
  end
end
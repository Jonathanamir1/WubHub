FactoryBot.define do
  factory :role do
    name { "collaborator" }
    association :project
    association :user

    trait :owner do
      name { "owner" }
    end

    trait :viewer do
      name { "viewer" }
    end
  end
end
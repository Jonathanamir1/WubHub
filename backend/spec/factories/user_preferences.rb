FactoryBot.define do
  factory :user_preference do
    key { "test_preference" }
    value { "test_value" }
    association :user  # ← This line is crucial!

    trait :workspace_order do
      key { UserPreference::WORKSPACE_ORDER }
      value { [1, 2, 3] }
    end

    trait :favorite_workspaces do
      key { UserPreference::FAVORITE_WORKSPACES }
      value { [1, 2] }
    end
  end
end
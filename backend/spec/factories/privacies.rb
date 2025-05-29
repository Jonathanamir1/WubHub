FactoryBot.define do
  factory :privacy do
    level { "inherited" }
    association :user
    
    trait :private_level do
      level { "private" }
    end
    
    trait :public_level do
      level { "public" }
    end
  end
end
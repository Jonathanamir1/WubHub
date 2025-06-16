# spec/factories/chunks.rb
FactoryBot.define do
  factory :chunk do
    association :upload_session
    sequence(:chunk_number) { |n| n }
    size { 1.megabyte }
    status { 'pending' }
    checksum { SecureRandom.hex(16) }
    
    trait :completed do
      status { 'completed' }
    end
    
    trait :failed do
      status { 'failed' }
    end
    
    trait :uploading do
      status { 'uploading' }
    end
    
    trait :large do
      size { 10.megabytes }
    end
    
    trait :small do
      size { 512.kilobytes }
    end
  end
end
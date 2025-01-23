# frozen_string_literal: true

FactoryBot.define do
  factory :intent_to_file, class: 'ClaimsApi::IntentToFile' do
    id { FactoryBot.generate(:uuid) }
    created_at { Time.zone.now }
    status { %w[pending errored submitted].sample }
    cid {
      %w[0oa9uf05lgXYk6ZXn297 0oa66qzxiq37neilh297 0oadnb0o063rsPupH297 0oadnb1x4blVaQ5iY297
         0oadnavva9u5F6vRz297 0oagdm49ygCSJTp8X297 0oaqzbqj9wGOCJBG8297 0oao7p92peuKEvQ73297].sample
    }
  end

  trait :itf_errored do
    status { 'errored' }
  end
end

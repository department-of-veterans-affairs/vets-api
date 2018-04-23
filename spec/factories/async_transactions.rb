FactoryBot.define do
  factory :async_transaction do
    
    sequence(:id) { |n| n }
    type                'AddressTransaction'
    user_uuid           'abcdb2b5-6af0-45e1-a9e2-394347af99'
    source_id           sequence(:id) { |n| n }
    source              'vet360'
    status              'started'
    transaction_id      sequence(:id) { |n| n }
    transaction_status  'RECEIVED'
    created_at           '2017-04-09T11:52:03-06:00'
    updated_at           '2017-04-09T11:52:03-06:00'

  end
end

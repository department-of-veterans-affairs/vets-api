# frozen_string_literal: true

FactoryBot.define do
  factory :address_transaction, class: AsyncTransaction::Vet360::AddressTransaction do
    sequence(:id, 1) { |n| n }
    user_uuid           'abcd789-6af0-45e1-a9e2-394347af99'
    sequence(:source_id) { |n| n }
    source              'vet360'
    status              'started'
    sequence(:transaction_id) { |n| n }
    transaction_status  'RECEIVED'
  end

  factory :email_transaction, class: AsyncTransaction::Vet360::EmailTransaction do
    sequence(:id, 200) { |n| n }
    user_uuid           'abcdb456-6af0-45e1-a9e2-394347af98'
    sequence(:source_id) { |n| n }
    source              'vet360'
    status              'started'
    sequence(:transaction_id) { |n| n }
    transaction_status  'RECEIVED'
  end

  factory :telephone_transaction, class: AsyncTransaction::Vet360::TelephoneTransaction do
    sequence(:id, 300) { |n| n }
    user_uuid           'abcdb123-6af0-45e1-a9e2-394347af97'
    sequence(:source_id) { |n| n }
    source              'vet360'
    status              'started'
    sequence(:transaction_id) { |n| n }
    transaction_status  'RECEIVED'
  end

end

# frozen_string_literal: true

FactoryBot.define do
  factory :address_transaction, class: AsyncTransaction::Vet360::AddressTransaction do
    sequence(:id) { |n| n }
    user_uuid           'abcdb2b5-6af0-45e1-a9e2-394347af99'
    sequence(:source_id) { |n| n }
    source              'vet360'
    status              'started'
    sequence(:transaction_id) { |n| n }
    transaction_status  'RECEIVED'
  end

end

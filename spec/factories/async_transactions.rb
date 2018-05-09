# frozen_string_literal: true

FactoryBot.define do
  factory :async_transaction, class: AsyncTransaction::Base do
    sequence(:user_uuid, 100) { |n| "abcd789-6af0-45e1-a9e2-394347a#{n}" }
    sequence(:source_id, &:to_s)
    source              'vet360'
    status              'requested'
    sequence(:transaction_id, 100) { |n| "r3fab2b5-6af0-45e1-a9e2-394347af9#{n}" }
    transaction_status 'RECEIVED'

    factory :address_transaction, class: AsyncTransaction::Vet360::AddressTransaction do
    end

    factory :email_transaction, class: AsyncTransaction::Vet360::EmailTransaction do
    end

    factory :telephone_transaction, class: AsyncTransaction::Vet360::TelephoneTransaction do
    end
  end
end

# frozen_string_literal: true

FactoryBot.define do
  factory :async_transaction, class: AsyncTransaction::Base do
    sequence(:id, 1) { |n| n }
    user_uuid 'abcd789-6af0-45e1-a9e2-394347af99'
    sequence(:source_id, &:to_s)
    source              'vet360'
    status              'started'
    sequence(:transaction_id, &:to_s)
    transaction_status 'RECEIVED'

    factory :address_transaction, class: AsyncTransaction::Vet360::AddressTransaction do
    end

    factory :email_transaction, class: AsyncTransaction::Vet360::EmailTransaction do
    end

    factory :telephone_transaction, class: AsyncTransaction::Vet360::TelephoneTransaction do
    end
  end
end

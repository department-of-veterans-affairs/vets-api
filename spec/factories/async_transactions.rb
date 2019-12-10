# frozen_string_literal: true

FactoryBot.define do
  factory :async_transaction, class: AsyncTransaction::Base do
    sequence(:user_uuid, 100) { |n| "abcd789-6af0-45e1-a9e2-394347a#{n}" }
    sequence(:source_id, &:to_s)
    source              { 'vet360' }
    status              { AsyncTransaction::Base::REQUESTED }
    sequence(:transaction_id, 100) { |n| "r3fab2b5-6af0-45e1-a9e2-394347af9#{n}" }
    transaction_status { 'RECEIVED' }

    factory :address_transaction, class: AsyncTransaction::Vet360::AddressTransaction do
    end

    factory :email_transaction, class: AsyncTransaction::Vet360::EmailTransaction do
    end

    factory :telephone_transaction, class: AsyncTransaction::Vet360::TelephoneTransaction do
    end

    factory :permission_transaction, class: AsyncTransaction::Vet360::PermissionTransaction do
    end

    factory :initialize_person_transaction, class: AsyncTransaction::Vet360::InitializePersonTransaction do
      trait :init_vet360_id do
        source_id { nil }
      end
    end

    factory :va526ez_submit_transaction, class: AsyncTransaction::EVSS::VA526ezSubmitTransaction do
      transaction_status { 'submitted' }
    end
  end
end

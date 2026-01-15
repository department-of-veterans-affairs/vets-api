# frozen_string_literal: true

FactoryBot.define do
  factory :async_transaction, class: 'AsyncTransaction::Base' do
    sequence(:user_uuid, 100) { |n| "abcd789-6af0-45e1-a9e2-394347a#{n}" }
    sequence(:source_id, &:to_s)
    source              { 'vet360' }
    status              { AsyncTransaction::Base::REQUESTED }
    sequence(:transaction_id, 100) { |n| "r3fab2b5-6af0-45e1-a9e2-394347af9#{n}" }
    transaction_status { 'RECEIVED' }
    metadata { '{ "key1": "value1", "key2": "value2" }' }

    factory :address_transaction, class: 'AsyncTransaction::VAProfile::AddressTransaction' do
    end

    factory :email_transaction, class: 'AsyncTransaction::VAProfile::EmailTransaction' do
    end

    factory :telephone_transaction, class: 'AsyncTransaction::VAProfile::TelephoneTransaction' do
    end

    factory :permission_transaction, class: 'AsyncTransaction::VAProfile::PermissionTransaction' do
    end

    factory :initialize_person_transaction, class: 'AsyncTransaction::VAProfile::InitializePersonTransaction' do
      trait :init_vet360_id do
        source_id { nil }
      end
    end

    factory :person_options_transaction, class: 'AsyncTransaction::VAProfile::PersonOptionsTransaction' do
    end

    factory :va_profile_address_transaction, class: 'AsyncTransaction::VAProfile::AddressTransaction' do
    end

    factory :va_profile_email_transaction, class: 'AsyncTransaction::VAProfile::EmailTransaction' do
    end

    factory :va_profile_telephone_transaction, class: 'AsyncTransaction::VAProfile::TelephoneTransaction' do
    end

    factory :va_profile_permission_transaction, class: 'AsyncTransaction::VAProfile::PermissionTransaction' do
    end

    factory :va_profile_initialize_person_transaction,
            class: 'AsyncTransaction::VAProfile::InitializePersonTransaction' do
      trait :init_vet360_id do
        source_id { nil }
      end
    end

    factory :va_profile_person_options_transaction, class: 'AsyncTransaction::VAProfile::PersonOptionsTransaction' do
    end
  end
end

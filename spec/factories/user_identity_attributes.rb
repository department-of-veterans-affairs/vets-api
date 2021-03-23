# frozen_string_literal: true

FactoryBot.define do
  factory :__base_user_identity_attrs, class: Hash do
    initialize_with { attributes }

    factory :user_identity_attrs do
      authn_context { 'http://idmanagement.gov/ns/assurance/loa/1/vets' }
      uuid { 'b2fab2b5-6af0-45e1-a9e2-394347af91ef' }
      email { 'abraham.lincoln@vets.gov' }
      first_name { 'abraham' }
      last_name { 'lincoln' }
      gender { 'M' }
      birth_date { '1809-02-12' }
      zip { '17325' }
      ssn { '796111863' }
      mhv_icn { nil }
      mhv_account_type { nil }
      sign_in { Hash[[[:service_name, 'idme']]] }
      loa { Hash[[[:current, LOA::ONE], [:highest, LOA::THREE]]] }

      trait :loa3 do
        authn_context { 'http://idmanagement.gov/ns/assurance/loa/3/vets' }
        loa { Hash[[[:current, LOA::THREE], [:highest, LOA::THREE]]] }
      end
    end

    factory :mhv_user_identity_attrs do
      authn_context { 'myhealthevet' }
      uuid { 'b2fab2b5-6af0-45e1-a9e2-394347af91ef' }
      email { Faker::Internet.email }
      first_name { nil }
      last_name { nil }
      gender { nil }
      birth_date { nil }
      zip { nil }
      ssn { nil }
      mhv_icn { nil }
      mhv_account_type { 'Basic' }
      sign_in { Hash[[[:service_name, 'myhealthevet']]] }
      loa { Hash[[[:current, LOA::ONE], [:highest, LOA::THREE]]] }
    end

    factory :dslogon_user_identity_attrs do
      authn_context { 'dslogon' }
      uuid { 'b2fab2b5-6af0-45e1-a9e2-394347af91ef' }
      email { Faker::Internet.email }
      first_name { nil }
      last_name { nil }
      gender { nil }
      birth_date { nil }
      zip { nil }
      ssn { nil }
      mhv_icn { nil }
      mhv_account_type { nil }
      sign_in { Hash[[[:service_name, 'dslogon']]] }
      loa { Hash[[[:current, LOA::ONE], [:highest, LOA::THREE]]] }
    end
  end
end

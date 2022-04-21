# frozen_string_literal: true

FactoryBot.define do
  factory :__base_user_identity_attrs, class: Hash do
    initialize_with { attributes }

    factory :user_identity_attrs do
      authn_context { 'http://idmanagement.gov/ns/assurance/loa/1/vets' }
      uuid { 'b2fab2b5-6af0-45e1-a9e2-394347af91ef' }
      icn { '1013062086V794840' }
      email { 'abraham.lincoln@vets.gov' }
      first_name { 'abraham' }
      last_name { 'lincoln' }
      gender { 'M' }
      birth_date { '1809-02-12' }
      zip { '17325' }
      ssn { '796111863' }
      mhv_icn { nil }
      mhv_account_type { nil }
      sign_in { [[:service_name, 'idme']].to_h }
      loa { [[:current, LOA::ONE], [:highest, LOA::THREE]].to_h }

      trait :loa3 do
        authn_context { 'http://idmanagement.gov/ns/assurance/loa/3/vets' }
        loa { [[:current, LOA::THREE], [:highest, LOA::THREE]].to_h }
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
      sign_in { [[:service_name, 'myhealthevet']].to_h }
      loa { [[:current, LOA::ONE], [:highest, LOA::THREE]].to_h }
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
      sign_in { [[:service_name, 'dslogon']].to_h }
      loa { [[:current, LOA::ONE], [:highest, LOA::THREE]].to_h }
    end
  end
end

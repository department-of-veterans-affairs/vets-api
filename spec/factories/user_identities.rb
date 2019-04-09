# frozen_string_literal: true

FactoryBot.define do
  factory :user_identity, class: 'UserIdentity' do
    authn_context 'http://idmanagement.gov/ns/assurance/loa/1/vets'
    uuid 'b2fab2b5-6af0-45e1-a9e2-394347af91ef'
    email 'abraham.lincoln@vets.gov'
    first_name 'abraham'
    last_name 'lincoln'
    gender 'M'
    birth_date '1809-02-12'
    zip '17325'
    ssn '796111863'
    mhv_icn nil
    mhv_account_type nil

    sign_in do
      {
        service_name: 'idme'
      }
    end

    loa do
      {
        current: LOA::ONE,
        highest: LOA::THREE
      }
    end
  end

  factory :mhv_user_identity, class: 'UserIdentity' do
    authn_context 'myhealthevet'
    uuid 'b2fab2b5-6af0-45e1-a9e2-394347af91ef'
    email { Faker::Internet.email }
    first_name nil
    last_name nil
    gender nil
    birth_date nil
    zip nil
    ssn nil
    mhv_icn nil
    mhv_account_type 'Basic'

    sign_in do
      {
        service_name: 'myhealthevet'
      }
    end

    loa do
      {
        current: LOA::ONE,
        highest: LOA::THREE
      }
    end
  end

  factory :dslogon_user_identity, class: 'UserIdentity' do
    authn_context 'dslogon'
    uuid 'b2fab2b5-6af0-45e1-a9e2-394347af91ef'
    email { Faker::Internet.email }
    first_name nil
    last_name nil
    gender nil
    birth_date nil
    zip nil
    ssn nil
    mhv_icn nil
    mhv_account_type nil

    sign_in do
      {
        service_name: 'dslogon'
      }
    end

    loa do
      {
        current: LOA::ONE,
        highest: LOA::THREE
      }
    end
  end

  trait :loa3 do
    authn_context 'http://idmanagement.gov/ns/assurance/loa/3/vets'

    sign_in do
      {
        service_name: 'idme'
      }
    end

    loa do
      { current: LOA::THREE, highest: LOA::THREE }
    end
  end
end

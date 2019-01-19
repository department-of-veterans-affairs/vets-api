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
    sign_in do
      {
        service_name: 'idme',
        account_type: 'N/A',
        id_proof_type: loa[:current] < loa[:highest] ? 'not-verified' : 'idme'
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
    uuid 'b2fab2b5-6af0-45e1-a9e2-394347af91ef'
    email { Faker::Internet.email }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    gender 'M'
    zip { Faker::Address.postcode }
    birth_date { Faker::Time.between(40.years.ago, 10.years.ago, :all) }
    ssn '796111864'
    mhv_account_type { 'Basic' }
    sign_in do
      {
        service_name: 'myhealthevet',
        account_type: mhv_account_type,
        id_proof_type: loa[:current] < loa[:highest] ? 'idme' : 'not-verified'
      }
    end

    loa do
      {
        current: LOA::THREE,
        highest: LOA::THREE
      }
    end
  end
end

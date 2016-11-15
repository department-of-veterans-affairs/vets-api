# frozen_string_literal: true
FactoryGirl.define do
  factory :user, class: 'User' do
    uuid 'b2fab2b5-6af0-45e1-a9e2-394347af91ef'
    email 'abraham.lincoln@vets.gov'
    first_name 'abraham'
    last_name 'lincoln'
    gender 'M'
    birth_date '1809-02-12'
    zip '17325'
    last_signed_in Time.now.utc
    ssn '272111863'
    loa do
      {
        current: LOA::TWO,
        highest: LOA::THREE
      }
    end

    factory :loa1_user do
      loa do
        {
          current: LOA::ONE,
          highest: LOA::ONE
        }
      end
    end

    factory :loa3_user do
      loa do
        {
          current: LOA::THREE,
          highest: LOA::THREE
        }
      end
    end
  end

  factory :mhv_user, class: 'User' do
    uuid 'b2fab2b5-6af0-45e1-a9e2-394347af91ef'
    edipi '1234'
    icn '1000123456V123456'
    mhv_last_signed_in Time.current
    participant_id '12345678'
    email 'abraham.lincoln@vets.gov'
    first_name 'abraham'
    last_name 'lincoln'
    birth_date Time.new(1809, 2, 12).utc
    ssn '272111863'
    mhv_last_signed_in Time.now.utc
    loa do
      {
        current: LOA::THREE,
        highest: LOA::THREE
      }
    end
    after(:build) do |mu|
      mu.stub(:mvi).and_return(
        status: 'NOT_FOUND',
        birth_date: '18090212',
        edipi: '1234^NI^200DOD^USDOD^A',
        vba_corp_id: '12345678^PI^200CORP^USVBA^A',
        family_name: 'Lincoln',
        gender: 'M',
        given_names: %w(Abraham),
        icn: '1000123456V123456^NI^200M^USVHA^P',
        mhv_ids: ['123456^PI^200MH^USVHA^A'],
        ssn: '272111863',
        active_status: 'active'
      )
    end

    trait :mhv_not_logged_in do
      mhv_last_signed_in nil
    end
  end
end

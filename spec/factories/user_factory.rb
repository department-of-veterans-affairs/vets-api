# frozen_string_literal: true
FactoryGirl.define do
  factory :user, class: 'User' do
    uuid 'b2fab2b5-6af0-45e1-a9e2-394347af91ef'
    email 'abraham.lincoln@vets.gov'
    first_name 'abraham'
    last_name 'lincoln'
    gender 'M'
    birth_date Time.new(1809, 2, 12).utc
    zip '17325'
    last_signed_in Time.now.utc
    edipi '1234^NI^200DOD^USDOD^A'
    ssn '272111863'
    loa do
      {
        current: LOA::TWO,
        highest: LOA::THREE
      }
    end

    factory :mvi_user do
      edipi '1234'
      icn '1000123456V123456'
      mhv_id '123456'
      participant_id '12345678'
      mvi do
        {
          birth_date: '18090212',
          edipi: '1234^NI^200DOD^USDOD^A',
          vba_corp_id: '12345678^PI^200CORP^USVBA^A',
          family_name: 'Lincoln',
          gender: 'M',
          given_names: %w(Abraham),
          icn: '1000123456V123456^NI^200M^USVHA^P',
          mhv_id: '123456^PI^200MH^USVHA^A',
          ssn: '272111863',
          status: 'active'
        }
      end
    end
  end

  factory :loa1_user, class: 'User' do
    uuid 'deadbeef-dead-beef-dead-deadbeefdead'
    email 'george.washington@vets.gov'
    loa do
      {
        current: LOA::ONE,
        highest: LOA::ONE
      }
    end
  end
end

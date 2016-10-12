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
      mvi do
        {
          edipi: '1234^NI^200DOD^USDOD^A',
          icn: '1000123456V123456^NI^200M^USVHA^P',
          mhv: '123456^PI^200MHV^USVHA^A',
          status: 'active',
          given_names: %w(abraham),
          family_name: 'lincoln',
          gender: 'M',
          birth_date: '18090212',
          ssn: '272111863'
        }
      end
    end
  end
end

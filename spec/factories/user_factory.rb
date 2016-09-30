# frozen_string_literal: true
FactoryGirl.define do
  factory :user, class: 'User' do
    uuid 'b2fab2b5-6af0-45e1-a9e2-394347af91ef'
    email 'john.smith@foo.org'
    first_name 'John'
    middle_name 'William'
    last_name 'Smith'
    gender 'M'
    dob Time.new(1980, 1, 1)
    zip '90210'
    last_signed_in Time.now.utc
    edipi '1234^NI^200DOD^USDOD^A'
    participant_id '123456789'
    ssn '555-44-3333'

    factory :user_with_mvi_data do
      mvi { {
        edipi: '1234^NI^200DOD^USDOD^A',
        icn: '1000123456V123456^NI^200M^USVHA^P',
        mhv: '123456^PI^200MHV^USVHA^A',
        status: 'active',
        given_names: %w(John William),
        family_name: 'Smith',
        gender: 'M',
        dob: '19800101',
        ssn: '555-44-3333'
      } }
    end
  end
end

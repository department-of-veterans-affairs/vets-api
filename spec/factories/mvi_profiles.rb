# frozen_string_literal: true

FactoryBot.define do
  factory :mvi_profile_address, class: 'MVI::Models::MviProfileAddress' do
    street { Faker::Address.street_address }
    city { Faker::Address.city }
    state { Faker::Address.state_abbr }
    postal_code { Faker::Address.zip }
    country 'USA'

    factory :mvi_profile_address_austin do
      street '121 A St'
      city 'Austin'
      state 'TX'
      postal_code '78772'
    end

    factory :mvi_profile_address_springfield do
      street '42 MAIN ST'
      city 'SPRINGFIELD'
      state 'IL'
      postal_code '62722'
    end
  end
end

FactoryBot.define do
  factory :mvi_profile, class: 'MVI::Models::MviProfile' do
    given_names { Array.new(2) { Faker::Name.first_name } }
    family_name { Faker::Name.last_name }
    suffix { Faker::Name.suffix }
    gender { Faker::Medical::Patient.gender }
    birth_date { Faker::Date.between(80.years.ago, 30.years.ago).strftime('%Y%m%d') }
    ssn { Faker::Medical::SSN.ssn.delete('-') }
    address { build(:mvi_profile_address) }
    home_phone { Faker::PhoneNumber.phone_number }
    icn { Faker::Number.number(17) }
    mhv_ids { Array.new(2) { Faker::Number.number(11) } }
    edipi { Faker::Number.number(10) }
    participant_id { Faker::Number.number(10) }
    birls_id { Faker::Number.number(10) }
    sec_id '0001234567'

    factory :mvi_profile_response do
      given_names %w[John William]
      family_name 'Smith'
      suffix 'Sr'
      gender 'M'
      birth_date '19800101'
      ssn '555443333'
      home_phone '1112223333'
      icn '1000123456V123456'
      mhv_ids ['123456']
      vha_facility_ids %w[516 553 200HD 200IP 200MHV]
      edipi '1234'
      participant_id '12345678'
      birls_id '796122306'

      trait :missing_attrs do
        given_names %w[Mitchell]
        family_name 'Jenkins'
        suffix nil
        birth_date '19490304'
        ssn '796122306'
        home_phone nil
        icn '1008714701V416111'
        mhv_ids nil
        vha_facility_ids ['200MHS']
        participant_id '9100792239'
        edipi nil
      end

      trait :multiple_mhvids do
        given_names %w[Steve A]
        family_name 'Ranger'
        suffix nil
        ssn '111223333'
        address { build(:mvi_profile_address_springfield) }
        home_phone '1112223333 p1'
        icn '12345678901234567'
        sec_id '0001234567'
        mhv_ids %w[12345678901 12345678902]
        vha_facility_ids %w[200MH 200MH]
        edipi '1122334455'
        participant_id '12345678'
        birls_id '123412345'
      end

      trait :address_austin do
        address { build(:mvi_profile_address_austin) }
      end
    end
  end
end

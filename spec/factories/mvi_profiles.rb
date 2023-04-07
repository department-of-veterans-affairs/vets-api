# frozen_string_literal: true

street = '49119 Jadon Mills'
street2 = 'Apt. 832'

FactoryBot.define do
  factory :street_check, class: Hash do
    street { street }
    street2 { street2 }
    initialize_with { attributes }
  end
end

FactoryBot.define do
  factory :mpi_profile_address, class: 'MPI::Models::MviProfileAddress' do
    street { "#{street}, #{street2}" }
    city { Faker::Address.city[0...20] }
    state { Faker::Address.state_abbr }
    postal_code { Faker::Address.zip }
    country { 'USA' }

    factory :mpi_profile_address_austin do
      street { '121 A St' }
      city { 'Austin' }
      state { 'TX' }
      postal_code { '78772' }
    end

    factory :mpi_profile_address_springfield do
      street { '42 MAIN ST' }
      city { 'SPRINGFIELD' }
      state { 'IL' }
      postal_code { '62722' }
    end
  end
end

FactoryBot.define do
  factory :mpi_profile, class: 'MPI::Models::MviProfile' do
    given_names { Array.new(1) { Faker::Name.first_name } }
    family_name { Faker::Name.last_name }
    suffix { Faker::Name.suffix }
    gender { %w[M F].sample }
    birth_date { Faker::Date.between(from: 80.years.ago, to: 30.years.ago).strftime('%Y%m%d') }
    deceased_date { nil }
    ssn { Faker::IDNumber.valid.delete('-') }
    address { build(:mpi_profile_address) }
    home_phone { Faker::PhoneNumber.phone_number }
    person_types { ['PAT'] }
    full_mvi_ids {
      [
        '1000123456V123456^NI^200M^USVHA^P',
        '12345^PI^516^USVHA^PCE',
        '2^PI^553^USVHA^PCE',
        '12345^PI^200HD^USVHA^A',
        'TKIP123456^PI^200IP^USVHA^A',
        '123456^PI^200MHV^USVHA^A',
        'UNK^NI^200DOD^USDOD^A',
        '12345678^PI^200CORP^USVBA^A'
      ]
    }
    icn { '1013062086V794840' }
    icn_with_aaid { '1000123456V123456^NI^200M^USVHA' }
    mhv_ids { Array.new(2) { Faker::Number.number(digits: 11) } }
    active_mhv_ids { mhv_ids }
    id_theft_flag { false }
    cerner_id { '123456' }
    cerner_facility_ids { %w[200MHV] }
    edipi { Faker::Number.number(digits: 10) }
    edipis { [edipi] }
    mhv_ien { Faker::Number.number(digits: 10) }
    mhv_iens { [mhv_ien] }
    participant_id { Faker::Number.number(digits: 10) }
    participant_ids { [participant_id] }
    birls = [Faker::Number.number(digits: 10)]
    birls_id { birls.first }
    birls_ids { birls }
    vet360_id { '123456789' }
    sec_id { '0001234567' }
    search_token { 'WSDOC2002071538432741110027956' }

    factory :mpi_profile_response do
      given_names { %w[John William] }
      family_name { 'Smith' }
      suffix { 'Sr' }
      gender { 'M' }
      birth_date { '19800101' }
      deceased_date { nil }
      id_theft_flag { false }
      ssn { '555443333' }
      home_phone { '1112223333' }
      full_mvi_ids {
        [
          '1000123456V123456^NI^200M^USVHA^P',
          '12345^PI^516^USVHA^PCE',
          '2^PI^553^USVHA^PCE',
          '12345^PI^200HD^USVHA^A',
          'TKIP123456^PI^200IP^USVHA^A',
          '123456^PI^200MHV^USVHA^A',
          '1234567890^NI^200DOD^USDOD^A',
          '87654321^PI^200CORP^USVBA^H',
          '12345678^PI^200CORP^USVBA^A',
          '123456789^PI^200VETS^USDVA^A'
        ]
      }
      icn { '1000123456V123456' }
      mhv_ids { ['123456'] }
      mhv_ien { '1100792239' }
      mhv_iens { ['1100792239'] }
      active_mhv_ids { ['123456'] }
      vha_facility_ids { %w[516 553 200HD 200IP 200MHV] }
      vha_facility_hash {
        {
          '516' => ['12345'],
          '553' => ['2'],
          '200HD' => ['12345'],
          '200IP' => ['TKIP123456'],
          '200MHV' => ['123456']
        }
      }
      edipi { '1234567890' }
      edipis { [edipi] }
      participant_id { '12345678' }
      participant_ids { [participant_id] }
      birls = ['796122306']
      birls_id { birls.first }
      birls_ids { birls }
      vet360_id { '123456789' }
      sec_id { '0001234567' }
      search_token { 'WSDOC2002071538432741110027956' }
      person_types { ['PAT'] }

      trait :with_nil_address do
        address { nil }
      end

      trait :with_relationship do
        relationships { [build(:mpi_profile_relationship)] }
      end

      trait :missing_attrs do
        given_names { %w[Mitchell] }
        family_name { 'Jenkins' }
        suffix { nil }
        birth_date { '19490304' }
        ssn { '796122306' }
        home_phone { nil }
        icn { '1008714701V416111' }
        birls_id { nil }
        birls_ids { [] }
        mhv_ids { nil }
        active_mhv_ids { nil }
        vha_facility_ids { ['200MHS'] }
        vha_facility_hash { { '200MHS' => ['1100792239'] } }
        participant_id { '9100792239' }
        edipi { nil }
        vet360_id { nil }
      end

      trait :multiple_mhvids do
        given_names { %w[Steve A] }
        family_name { 'Ranger' }
        suffix { nil }
        ssn { '111223333' }
        address { build(:mpi_profile_address_springfield) }
        home_phone { '1112223333 p1' }
        icn { '12345678901234567' }
        sec_id { '0001234567' }
        mhv_ids { %w[12345678901 12345678902] }
        active_mhv_ids { %w[12345678901] }
        vha_facility_ids { %w[200MH 200MH] }
        vha_facility_hash { { '200MH' => %w[12345678901 12345678902] } }
        edipi { '1122334455' }
        participant_id { '12345678' }
        birls = ['123412345']
        birls_id { birls.first }
        birls_ids { birls }
        vet360_id { nil }
      end

      trait :address_austin do
        address { build(:mpi_profile_address_austin) }
      end
    end
  end
end

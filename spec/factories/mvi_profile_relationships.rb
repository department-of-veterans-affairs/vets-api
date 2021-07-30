# frozen_string_literal: true

FactoryBot.define do
  factory :mpi_profile_relationship, class: 'MPI::Models::MviProfileRelationship' do
    person_types { ['VET'] }
    given_names { %w[Joe William] }
    family_name { 'Smith' }
    suffix { 'Sr' }
    gender { 'M' }
    birth_date { '19500101' }
    ssn { '955443333' }
    address { nil }
    home_phone { '1112223377' }
    full_mvi_ids {
      [
        '9900123456V123456^NI^200M^USVHA^P',
        '99345^PI^916^USVHA^PCE',
        '2^PI^593^USVHA^PCE',
        '99345^PI^200HD^USVHA^A',
        'TKIP993456^PI^200IP^USVHA^A',
        '993456^PI^200MHV^USVHA^A',
        '9934567890^NI^200DOD^USDOD^A',
        '99654321^PI^200CORP^USVBA^H',
        '99345678^PI^200CORP^USVBA^A',
        '993456789^PI^200VETS^USDVA^A',
        '9923454432^PI^200CRNR^USVHA^A'
      ]
    }
    icn { '9900123456V123456' }
    mhv_ids { ['993456'] }
    active_mhv_ids { ['993456'] }
    edipi { '9934567890' }
    participant_id { '99345678' }
    vha_facility_ids { %w[916 593 200HD 200IP 200MHV] }
    sec_id { '9901234567' }
    birls_id { birls_ids.first }
    birls_ids { ['996122306'] }
    vet360_id { '993456789' }
    icn_with_aaid { '9900123456V123456^NI^200M^USVHA' }
    cerner_id { '9923454432' }
    cerner_facility_ids { ['200CRNR'] }
  end
end

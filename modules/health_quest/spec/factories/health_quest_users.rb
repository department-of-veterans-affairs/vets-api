# frozen_string_literal: true

FactoryBot.modify do
  factory :user do
    trait :health_quest do
      authn_context { 'http://idmanagement.gov/ns/assurance/loa/1/vets' }
      uuid { '3071ca1783954ec19170f3c4bdfd0c95' }
      last_signed_in { Time.now.utc }
      mhv_last_signed_in { Time.now.utc }
      email { 'judy.morrison@id.me' }
      first_name { 'Judy' }
      middle_name { 'Snow' }
      last_name { 'Morrison' }
      gender { 'F' }
      birth_date { '1953-04-01' }
      ssn { '796061976' }
      va_patient { true }

      loa do
        {
          current: LOA::THREE,
          highest: LOA::THREE
        }
      end

      # add an MHV correlation_id and vha_facility_ids corresponding to va_patient
      after(:build) do |user, _t|
        profile = build(
          :mpi_profile,
          given_names: %w[Judy Snow],
          family_name: 'Morrison',
          suffix: nil,
          address: nil,
          home_phone: '(732)476-4626',
          edipi: '1259897978',
          birls_id: nil,
          vet360_id: '63807',
          full_mvi_ids: %w[
            1012845331V153043^NI^200M^USVHA^P 1259897978^NI^200DOD^USDOD^A 0000027819^PN^200PROV^USDVA^A
            7216691^PI^983^USVHA^A 552161050^PI^984^USVHA^A 63807^PI^200VETS^USDVA^A
            3071ca1783954ec19170f3c4bdfd0c95^PN^200VIDM^USDVA^A 16701377^PI^200MHS^USVHA^A
            0000001012845331V153043000000^PI^200ESR^USVHA^A UNK^PI^200BRLS^USVBA^FAULT UNK^PI^200CORP^USVBA^FAULT
          ],
          icn: '1012845331V153043',
          icn_with_aaid: '1012845331V153043^NI^200M^USVHA',
          mhv_ids: ['16701377'],
          vha_facility_ids: %w[983 984 200MHS 200ESR],
          gender: 'F',
          birth_date: '19530401',
          ssn: '796061976'
        )
        mvi = MPIData.for_user(user)
        profile_response = create(:find_profile_response, profile:)
        mvi.instance_variable_set(:@mvi_response, profile_response)
        mvi.send(:do_cached_with, key: mvi.send(:get_user_key)) do
          profile_response
        end
        user.instance_variable_set(:@mpi, mvi)
      end
    end
  end
end

# frozen_string_literal: true

FactoryBot.modify do
  factory :user do
    trait :vaos do
      authn_context { 'http://idmanagement.gov/ns/assurance/loa/1/vets' }
      uuid { SecureRandom.uuid }
      last_signed_in { Time.now.utc }
      mhv_last_signed_in { Time.now.utc }
      email { 'vets.gov.user+228@gmail.com' }
      first_name { 'JUDY' }
      last_name { 'MORRISON' }
      gender { 'F' }
      zip { '12345' }
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
      after(:build) do |user, t|
        profile = build(
          :mvi_profile,
          given_names: %w[Judy Snow],
          family_name: 'Morrison',
          suffix: nil,
          address: nil,
          home_phone: nil,
          edipi: '1259897978',
          birls_id: nil,
          vet360_id: '63807',
          full_mvi_ids: %w[1012845331V153043^NI^200M^USVHA^P],
          icn: '1012845331V153043',
          icn_with_aaid: '1012845331V153043^NI^200M^USVHA',
          mhv_ids: [],
          vha_facility_ids: t.va_patient ? %w[983 984 200ESR] : [],
          historical_icns: [],
          gender: 'F',
          birth_date: '1953-04-01',
          ssn: '796061976'
        )
        mvi = Mvi.for_user(user)
        profile_response = MVI::Responses::FindProfileResponse.new(
          status: MVI::Responses::FindProfileResponse::RESPONSE_STATUS[:ok],
          profile: profile
        )
        mvi.instance_variable_set(:@mvi_response, profile_response)
        mvi.send(:do_cached_with, key: user.uuid) do
          profile_response
        end
        user.instance_variable_set(:@mvi, mvi)
      end
    end
  end
end

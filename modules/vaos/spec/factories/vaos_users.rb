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

      loa do
        {
          current: LOA::THREE,
          highest: LOA::THREE
        }
      end

      # add an MHV correlation_id and vha_facility_ids corresponding to va_patient
      after(:build) do |_user, t|
        stub_mvi(
          build(
            :mvi_profile,
            full_mvi_ids: %w[1012845331V153043^NI^200M^USVHA^P],
            icn: '1012845331V153043',
            icn_with_aaid: '1012845331V153043^NI^200M^USVHA',
            mhv_ids: [],
            vha_facility_ids: t.va_patient ? %w[983 984 200ESR] : [],
            gender: 'F',
            birth_date: '1953-04-01',
            ssn: '796061976'
          )
        )
      end
    end
  end
end

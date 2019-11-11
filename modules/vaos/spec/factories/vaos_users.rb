FactoryBot.modify do
  factory :user do
    trait :vaos do
      authn_context { 'http://idmanagement.gov/ns/assurance/loa/1/vets' }
      uuid { SecureRandom.uuid }
      last_signed_in { Faker::Time.between(2.years.ago, 1.week.ago, :all) }
      mhv_last_signed_in { Faker::Time.between(1.week.ago, 1.minute.ago, :all) }
      email { 'vets.gov.user+228@gmail.com' }
      first_name { 'JUDY' }
      last_name { 'MORRISON' }
      gender { 'F' }
      zip { Faker::Address.postcode }
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
            :mvi_profile
            full_mvi_ids: %w[
              1012845331V153043^NI^200M^USVHA^P
              1259897978^NI^200DOD^USDOD^A
              0000027819^PN^200PROV^USDVA^A
              7216691^PI^983^USVHA^A
              552161050^PI^984^USVHA^A
              63807^PI^200VETS^USDVA^A
              0000001012845331V153043000000^PI^200ESR^USVHA^A
              UNK^PI^200BRLS^USVBA^FAULT
              UNK^PI^200CORP^USVBA^FAULT
            ],
            icn: '1012845331V153043',
            icn_with_aaid: '1012845331V153043^NI^200M^USVHA',
            mhv_ids: [],
            vha_facility_ids: t.va_patient ? %w[983 984 200ESR] : []
          )
        )
      end
    end
  end
end

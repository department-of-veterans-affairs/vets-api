# frozen_string_literal: true

FactoryBot.define do
  factory :user, class: 'User' do
    uuid { 'b2fab2b5-6af0-45e1-a9e2-394347af91ef' }
    last_signed_in { Time.now.utc }
    transient do
      authn_context { LOA::IDME_LOA1_VETS }
      email { 'abraham.lincoln@vets.gov' }
      first_name { 'abraham' }
      middle_name { nil }
      last_name { 'lincoln' }
      gender { 'M' }
      birth_date { '1809-02-12' }
      zip { '17325' }
      ssn { '796111863' }
      idme_uuid { 'b2fab2b5-6af0-45e1-a9e2-394347af91ef' }
      logingov_uuid { nil }
      sec_id { '123498767' }
      participant_id { nil }
      birls_id { nil }
      icn { '123498767V234859' }
      mhv_icn { nil }
      multifactor { false }
      mhv_correlation_id { nil }
      mhv_account_type { nil }
      edipi { '384759483' }
      va_patient { nil }
      search_token { nil }
      icn_with_aaid { nil }
      common_name { nil }
      person_types { ['VET'] }

      sign_in do
        {
          service_name: SAML::User::AUTHN_CONTEXTS[authn_context][:sign_in][:service_name]
        }
      end

      loa do
        { current: LOA::ONE, highest: LOA::THREE }
      end
    end

    callback(:after_build, :after_stub, :after_create) do |user, t|
      user_identity = create(:user_identity,
                             authn_context: t.authn_context,
                             uuid: user.uuid,
                             email: t.email,
                             first_name: t.first_name,
                             middle_name: t.middle_name,
                             last_name: t.last_name,
                             gender: t.gender,
                             birth_date: t.birth_date,
                             zip: t.zip,
                             ssn: t.ssn,
                             idme_uuid: t.idme_uuid,
                             logingov_uuid: t.logingov_uuid,
                             sec_id: t.sec_id,
                             participant_id: t.participant_id,
                             birls_id: t.birls_id,
                             icn: t.icn,
                             mhv_icn: t.mhv_icn,
                             loa: t.loa,
                             person_types: t.person_types,
                             multifactor: t.multifactor,
                             mhv_correlation_id: t.mhv_correlation_id,
                             mhv_account_type: t.mhv_account_type,
                             edipi: t.edipi,
                             sign_in: t.sign_in,
                             common_name: t.common_name)
      user.instance_variable_set(:@identity, user_identity)
    end

    # This is used by the response_builder helper to build a user from saml attributes
    trait :response_builder do
      authn_context { nil }
      uuid { nil }
      last_signed_in { Faker::Time.between(from: 2.years.ago, to: 1.week.ago) }
      mhv_last_signed_in { Faker::Time.between(from: 1.week.ago, to: 1.minute.ago) }
      email { nil }
      first_name { nil }
      last_name { nil }
      gender { nil }
      zip { nil }
      birth_date { nil }
      ssn { nil }
      multifactor { nil }
      idme_uuid { nil }
      mhv_account_type { nil }
      va_patient { nil }
      loa { nil }
    end

    trait :dependent do
      person_types { ['DEP'] }
    end

    trait :accountable do
      authn_context { LOA::IDME_LOA3_VETS }
      uuid { '9d018700-b72c-444a-95b4-43e14a4509ea' }
      idme_uuid { '9d018700-b72c-444a-95b4-43e14a4509ea' }
      callback(:after_build) do |user|
        create(:account, idme_uuid: user.idme_uuid)
      end

      sign_in do
        {
          service_name: SAML::User::AUTHN_CONTEXTS[authn_context][:sign_in][:service_name]
        }
      end

      loa do
        { current: LOA::THREE, highest: LOA::THREE }
      end
    end

    trait :accountable_with_sec_id do
      authn_context { LOA::IDME_LOA3_VETS }
      uuid { '378250b8-28b1-4366-a377-445d04fcd3d5' }
      idme_uuid { '378250b8-28b1-4366-a377-445d04fcd3d5' }
      callback(:after_build) do |user|
        create(:account, sec_id: user.sec_id)
      end

      sign_in do
        {
          service_name: SAML::User::AUTHN_CONTEXTS[authn_context][:sign_in][:service_name]
        }
      end

      loa do
        { current: LOA::THREE, highest: LOA::THREE }
      end
    end

    trait :accountable_with_logingov_uuid do
      authn_context { LOA::IDME_LOA3_VETS }
      uuid { '378250b8-28b1-4366-a377-445d04fcd3d5' }
      logingov_uuid { '2j4250b8-28b1-4366-a377-445dfj49turh' }
      callback(:after_build) do |user|
        create(:account, logingov_uuid: user.logingov_uuid)
      end

      sign_in do
        {
          service_name: SAML::User::AUTHN_CONTEXTS[authn_context][:sign_in][:service_name]
        }
      end

      loa do
        { current: LOA::THREE, highest: LOA::THREE }
      end
    end

    trait :loa1 do
      authn_context { LOA::IDME_LOA1_VETS }
      sign_in do
        {
          service_name: SAML::User::AUTHN_CONTEXTS[authn_context][:sign_in][:service_name]
        }
      end

      loa do
        { current: LOA::ONE, highest: LOA::ONE }
      end
    end

    trait :loa3 do
      authn_context { LOA::IDME_LOA3_VETS }

      sign_in do
        {
          service_name: SAML::User::AUTHN_CONTEXTS[authn_context][:sign_in][:service_name]
        }
      end

      loa do
        { current: LOA::THREE, highest: LOA::THREE }
      end
    end

    factory :user_with_no_ids, traits: [:loa3] do
      after(:build) do
        stub_mpi(
          build(
            :mvi_profile,
            birls_id: nil,
            participant_id: nil
          )
        )
      end
    end

    factory :user_with_no_birls_id, traits: [:loa3] do
      after(:build) do
        stub_mpi(
          build(
            :mvi_profile,
            birls_id: nil
          )
        )
      end
    end

    factory :user_with_no_secid, traits: [:loa3] do
      after(:build) do
        stub_mpi(
          build(
            :mvi_profile,
            sec_id: nil
          )
        )
      end
    end

    factory :user_with_relationship, traits: [:loa3] do
      after(:build) do
        stub_mpi(
          build(
            :mpi_profile_response,
            :with_relationship
          )
        )
      end
    end

    factory :vets360_user, traits: [:loa3] do
      after(:build) do
        stub_mpi(
          build(
            :mvi_profile,
            vet360_id: '1411684'
          )
        )
      end
    end

    factory :evss_user, traits: [:loa3] do
      first_name { 'WESLEY' }
      last_name { 'FORD' }
      edipi { nil }
      last_signed_in { Time.zone.parse('2017-12-07T00:55:09Z') }
      ssn { '796043735' }

      after(:build) do
        stub_mpi(
          build(
            :mvi_profile,
            edipi: '1007697216',
            birls_id: '796043735',
            participant_id: '600061742',
            birth_date: '1986-05-06T00:00:00+00:00'.to_date.to_s
          )
        )
      end
    end

    factory :no_dob_evss_user, traits: [:loa3] do
      first_name { 'WESLEY' }
      last_name { 'FORD' }
      last_signed_in { Time.zone.parse('2017-12-07T00:55:09Z') }
      ssn { '796043735' }

      after(:build) do
        stub_mpi(
          build(
            :mvi_profile,
            edipi: '1007697216',
            birls_id: '796043735',
            participant_id: '600061742',
            birth_date: nil
          )
        )
      end
    end

    factory :unauthorized_evss_user, traits: [:loa3] do
      first_name { 'WESLEY' }
      last_name { 'FORD' }
      edipi { nil }
      last_signed_in { Time.zone.parse('2017-12-07T00:55:09Z') }
      ssn { '796043735' }

      after(:build) do
        stub_mpi(
          build(
            :mvi_profile,
            edipi: nil,
            birls_id: '796043735',
            participant_id: nil,
            birth_date: '1986-05-06T00:00:00+00:00'.to_date.to_s
          )
        )
      end
    end

    factory :disabilities_compensation_user, traits: [:loa3] do
      first_name { 'Beyonce' }
      last_name { 'Knowles' }
      gender { 'F' }
      last_signed_in { Time.zone.parse('2017-12-07T00:55:09Z') }
      ssn { '796068949' }

      transient do
        multifactor { true }
      end

      after(:build) do
        stub_mpi(build(:mvi_profile, birls_id: '796068948'))
      end
    end

    factory :unauthorized_bgs_user, traits: [:loa3] do
      first_name { 'Charles' }
      last_name { 'Bronson' }
      last_signed_in { Time.zone.parse('2017-12-07T00:55:09Z') }
      ssn { nil }

      after(:build) do
        stub_mpi(
          build(
            :mvi_profile,
            edipi: '1007697216',
            birls_id: '796043735',
            participant_id: nil,
            icn: nil,
            birth_date: '1986-05-06T00:00:00+00:00'.to_date.to_s
          )
        )
      end
    end

    factory :blank_gender_user do
      gender { '' }
      after(:build) do
        stub_mpi(
          build(
            :mvi_profile,
            edipi: '1007697216',
            birls_id: '796043735',
            participant_id: nil,
            icn: nil,
            birth_date: '1986-05-06T00:00:00+00:00'.to_date.to_s
          )
        )
      end
    end

    factory :user_with_suffix, traits: [:loa3] do
      first_name { 'Jack' }
      middle_name { 'Robert' }
      last_name { 'Smith' }
      last_signed_in { Time.zone.parse('2017-12-07T00:55:09Z') }
      ssn { '796043735' }

      after(:build) do
        stub_mpi(
          build(
            :mpi_profile_response,
            edipi: '1007697216',
            birls_id: '796043735',
            participant_id: '600061742',
            birth_date: '1986-05-06T00:00:00+00:00'.to_date.to_s
          )
        )
      end
    end

    factory :ch33_dd_user, traits: [:loa3] do
      ssn { '796104437' }
      icn { nil }

      after(:build) do
        stub_mpi(
          build(
            :mvi_profile,
            icn: '82836359962678900'
          )
        )

        allow(BGS.configuration).to receive(:env).and_return('prepbepbenefits')
        allow(BGS.configuration).to receive(:client_ip).and_return('10.247.35.119')
      end
    end

    trait :user_with_no_idme_uuid do
      uuid { '133e619f-7b69-4e7a-b571-e4c9478d0a04' }
      sec_id { '1234' }
      idme_uuid { nil }

      sign_in do
        {
          service_name: SAML::User::AUTHN_CONTEXTS[authn_context][:sign_in][:service_name]
        }
      end

      loa do
        { current: LOA::THREE, highest: LOA::THREE }
      end
    end

    trait :user_with_no_idme_uuid_or_sec_id do
      uuid { '133e619f-7b69-4e7a-b571-e4c9478d0a04' }
      sec_id { nil }
      logingov_uuid { '256f723a-7b69-4e7a-b571-e4c94785jgof' }
      idme_uuid { nil }

      sign_in do
        {
          service_name: SAML::User::AUTHN_CONTEXTS[authn_context][:sign_in][:service_name]
        }
      end

      loa do
        { current: LOA::THREE, highest: LOA::THREE }
      end

      after(:build) do
        stub_mpi(
          build(
            :mvi_profile,
            sec_id: nil
          )
        )
      end
    end

    trait :mhv_sign_in do
      authn_context { 'myhealthevet' }
      mhv_account_type { 'Basic' }
      email { 'abraham.lincoln@vets.gov' }
      first_name { nil }
      middle_name { nil }
      last_name { nil }
      gender { nil }
      birth_date { nil }
      zip { nil }
      ssn { nil }
      mhv_icn { '12345' }
      multifactor { false }
    end

    trait :mhv do
      authn_context { 'myhealthevet' }
      uuid { 'b2fab2b5-6af0-45e1-a9e2-394347af91ef' }
      idme_uuid { 'b2fab2b5-6af0-45e1-a9e2-394347af91ef' }
      last_signed_in { Faker::Time.between(from: 2.years.ago, to: 1.week.ago) }
      mhv_last_signed_in { Faker::Time.between(from: 1.week.ago, to: 1.minute.ago) }
      email { Faker::Internet.email }
      first_name { Faker::Name.first_name }
      last_name { Faker::Name.last_name }
      icn { nil }
      gender { 'M' }
      zip { Faker::Address.postcode }
      birth_date { Faker::Time.between(from: 40.years.ago, to: 10.years.ago) }
      ssn { '796111864' }
      multifactor { true }
      mhv_account_type { 'Premium' }
      va_patient { true }

      sign_in do
        {
          service_name: 'myhealthevet'
        }
      end

      loa do
        {
          current: LOA::THREE,
          highest: LOA::THREE
        }
      end

      # add an MHV correlation_id and vha_facility_ids corresponding to va_patient
      after(:build) do |_user, t|
        stub_mpi(
          build(
            :mvi_profile,
            icn: '1000123456V123456',
            mhv_ids: %w[12345678901],
            vha_facility_ids: t.va_patient ? %w[358 200MHS] : []
          )
        )
      end
    end

    trait :mhv_not_logged_in do
      mhv_last_signed_in { nil }
    end

    trait :dslogon do
      authn_context { 'dslogon' }
      uuid { 'b2fab2b5-6af0-45e1-a9e2-394347af91ef' }
      idme_uuid { 'b2fab2b5-6af0-45e1-a9e2-394347af91ef' }
      last_signed_in { Faker::Time.between(from: 2.years.ago, to: 1.week.ago) }
      mhv_last_signed_in { nil }
      email { Faker::Internet.email }
      first_name { Faker::Name.first_name }
      last_name { Faker::Name.last_name }
      gender { 'M' }
      zip { Faker::Address.postcode }
      birth_date { Faker::Time.between(from: 40.years.ago, to: 10.years.ago) }
      ssn { '796111864' }
      multifactor { true }
      mhv_account_type { nil }
      va_patient { true }

      sign_in do
        {
          service_name: 'dslogon'
        }
      end

      loa do
        {
          current: LOA::THREE,
          highest: LOA::THREE
        }
      end

      # add an MHV correlation_id and vha_facility_ids corresponding to va_patient
      after(:build) do |_user, t|
        stub_mpi(
          build(
            :mvi_profile,
            icn: '1000123456V123456',
            mhv_ids: %w[12345678901],
            vha_facility_ids: t.va_patient ? %w[358] : []
          )
        )
      end
    end
  end
end

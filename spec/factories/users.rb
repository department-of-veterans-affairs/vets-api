# frozen_string_literal: true

require 'saml/url_service'

FactoryBot.define do
  factory :user, class: 'User' do
    uuid { user_verification.user_account.id }
    last_signed_in { Time.now.utc }
    fingerprint { '111.111.1.1' }
    session_handle { SecureRandom.hex }
    transient do
      icn do
        digits = Faker::Number.number(digits: 16).to_s
        "#{digits[0..9]}V#{digits[10..]}"
      end
      user_account { create(:user_account, icn:) }
      user_verification { create(:user_verification, user_account:, idme_uuid:, logingov_uuid:) }
      authn_context { LOA::IDME_LOA1_VETS }
      email { 'abraham.lincoln@vets.gov' }
      first_name { 'abraham' }
      middle_name { nil }
      last_name { 'lincoln' }
      gender { 'M' }
      preferred_name { 'abe' }
      birth_date { '1809-02-12' }
      ssn { '796111863' }
      idme_uuid { Faker::Alphanumeric.alphanumeric(number: 32) }
      logingov_uuid { nil }
      verified_at { nil }
      sec_id { '123498767' }
      participant_id { Faker::Number.number(digits: 8) }
      birls_id { Faker::Number.number(digits: 9) }
      mhv_icn { nil }
      multifactor { false }
      mhv_ids { [mhv_credential_uuid] }
      active_mhv_ids { [mhv_credential_uuid] }
      mhv_correlation_id { mhv_credential_uuid }
      mhv_credential_uuid { Faker::Number.number(digits: 9) }
      mhv_account_type { nil }
      edipi { '384759483' }
      va_patient { nil }
      search_token { nil }
      icn_with_aaid { nil }
      common_name { nil }
      person_types { ['VET'] }
      home_phone { '(800) 867-5309' }
      needs_accepted_terms_of_use { false }
      suffix { 'Jr' }
      address do
        {
          street: '1600 Pennsylvania Ave',
          city: 'Washington',
          state: 'DC',
          country: 'USA',
          postal_code: '20500'
        }
      end
      cerner_id { '123456' }
      cerner_facility_ids { %w[200MHV] }
      vha_facility_ids { %w[200CRNR 200MHV] }
      vha_facility_hash { { '200CRNR' => %w[123456], '200MHV' => %w[123456] } }
      vet360_id { '1' }
      should_stub_mpi { true }

      sign_in do
        {
          service_name: SAML::User::AUTHN_CONTEXTS[authn_context][:sign_in][:service_name],
          auth_broker: SAML::URLService::BROKER_CODE,
          client_id: SAML::URLService::UNIFIED_SIGN_IN_CLIENTS.first
        }
      end

      loa do
        { current: LOA::ONE, highest: LOA::THREE }
      end

      user_identity do
        { authn_context:,
          uuid:,
          email:,
          first_name:,
          middle_name:,
          last_name:,
          gender:,
          birth_date:,
          ssn:,
          idme_uuid:,
          logingov_uuid:,
          verified_at:,
          sec_id:,
          icn:,
          mhv_icn:,
          loa:,
          multifactor:,
          mhv_credential_uuid:,
          mhv_account_type:,
          edipi:,
          sign_in: }
      end

      mpi_profile do
        given_names = [first_name]
        given_names << middle_name if middle_name.present?
        preferred_names = [preferred_name]

        mpi_attributes = { active_mhv_ids:,
                           address:,
                           birls_id:,
                           birth_date:,
                           cerner_id:,
                           cerner_facility_ids:,
                           edipi:,
                           family_name: last_name,
                           gender:,
                           given_names:,
                           preferred_names:,
                           home_phone:,
                           icn:,
                           mhv_ids:,
                           participant_id:,
                           person_types:,
                           ssn:,
                           suffix:,
                           vha_facility_ids:,
                           vha_facility_hash:,
                           vet360_id: }
        FactoryBot.build(:mpi_profile, mpi_attributes)
      end

      mhv_user_account do
        FactoryBot.build(:mhv_user_account)
      end
    end

    callback(:after_build, :after_stub, :after_create) do |user, t|
      user_identity = create(:user_identity, t.user_identity)
      user.instance_variable_set(:@identity, user_identity)
      user.instance_variable_set(:@needs_accepted_terms_of_use, t.needs_accepted_terms_of_use)
      stub_mpi(t.mpi_profile) unless t.should_stub_mpi == false
    end

    # This is used by the response_builder helper to build a user from saml attributes
    trait :response_builder do
      authn_context { nil }
      last_signed_in { Faker::Time.between(from: 2.years.ago, to: 1.week.ago) }
      mhv_last_signed_in { Faker::Time.between(from: 1.week.ago, to: 1.minute.ago) }
      email { nil }
      first_name { nil }
      last_name { nil }
      gender { nil }
      birth_date { nil }
      ssn { nil }
      multifactor { nil }
      idme_uuid { nil }
      logingov_uuid { nil }
      verified_at { nil }
      mhv_account_type { nil }
      va_patient { nil }
      loa { nil }
    end

    trait :legacy_icn do
      icn { '123498767V234859' }
    end

    trait :dependent do
      person_types { ['DEP'] }
    end

    trait :accountable do
      authn_context { LOA::IDME_LOA3_VETS }
      uuid { '9d018700-b72c-444a-95b4-43e14a4509ea' }
      idme_uuid { '9d018700-b72c-444a-95b4-43e14a4509ea' }

      sign_in do
        {
          service_name: SAML::User::AUTHN_CONTEXTS[authn_context][:sign_in][:service_name],
          auth_broker: SAML::URLService::BROKER_CODE,
          client_id: SAML::URLService::UNIFIED_SIGN_IN_CLIENTS.first
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

      sign_in do
        {
          service_name: SAML::User::AUTHN_CONTEXTS[authn_context][:sign_in][:service_name],
          auth_broker: SAML::URLService::BROKER_CODE,
          client_id: SAML::URLService::UNIFIED_SIGN_IN_CLIENTS.first
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

      sign_in do
        {
          service_name: SAML::User::AUTHN_CONTEXTS[authn_context][:sign_in][:service_name],
          auth_broker: SAML::URLService::BROKER_CODE,
          client_id: SAML::URLService::UNIFIED_SIGN_IN_CLIENTS.first
        }
      end

      loa do
        { current: LOA::THREE, highest: LOA::THREE }
      end
    end

    trait :loa1 do
      should_stub_mpi { false }
      authn_context { LOA::IDME_LOA1_VETS }
      sign_in do
        {
          service_name: SAML::User::AUTHN_CONTEXTS[authn_context][:sign_in][:service_name],
          auth_broker: SAML::URLService::BROKER_CODE,
          client_id: SAML::URLService::UNIFIED_SIGN_IN_CLIENTS.first
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
          service_name: SAML::User::AUTHN_CONTEXTS[authn_context][:sign_in][:service_name],
          auth_broker: SAML::URLService::BROKER_CODE,
          client_id: SAML::URLService::UNIFIED_SIGN_IN_CLIENTS.first
        }
      end

      loa do
        { current: LOA::THREE, highest: LOA::THREE }
      end
    end

    trait :ial1 do
      should_stub_mpi { false }
      uuid { '42fc7a21-c05f-4e6b-9985-67d11e2fbf76' }
      logingov_uuid { '42fc7a21-c05f-4e6b-9985-67d11e2fbf76' }
      verified_at { '2021-11-09T16:46:27Z' }
      authn_context { IAL::LOGIN_GOV_IAL1 }
      sign_in do
        {
          service_name: SAML::User::AUTHN_CONTEXTS[authn_context][:sign_in][:service_name],
          auth_broker: SAML::URLService::BROKER_CODE,
          client_id: SAML::URLService::UNIFIED_SIGN_IN_CLIENTS.first
        }
      end

      loa do
        { current: LOA::ONE, highest: LOA::ONE }
      end
    end

    trait :no_mpi_profile do
      should_stub_mpi { false }
    end

    factory :logingov_ial1_user, traits: [:ial1] do
    end

    factory :user_with_no_ids, traits: [:loa3] do
      birls_id { nil }
      participant_id { nil }
    end

    factory :dependent_user_with_relationship, traits: %i[loa3 dependent] do
      should_stub_mpi { false }

      after(:build) do
        stub_mpi(
          FactoryBot.build(
            :mpi_profile_response,
            :with_relationship,
            person_types: ['DEP']
          )
        )
      end
    end

    factory :user_with_relationship, traits: [:loa3] do
      should_stub_mpi { false }

      after(:build) do |_t|
        stub_mpi(
          FactoryBot.build(
            :mpi_profile_response,
            :with_relationship
          )
        )
      end
    end

    factory :evss_user, traits: [:loa3] do
      first_name { 'WESLEY' }
      last_name { 'FORD' }
      edipi { '1007697216' }
      birls_id { '796043735' }
      participant_id { '600061742' }
      last_signed_in { Time.zone.parse('2017-12-07T00:55:09Z') }
      birth_date { '1986-05-06T00:00:00+00:00'.to_date.to_s }
      ssn { '796043735' }
    end

    factory :unauthorized_evss_user, traits: [:loa3] do
      first_name { 'WESLEY' }
      last_name { 'FORD' }
      edipi { nil }
      last_signed_in { Time.zone.parse('2017-12-07T00:55:09Z') }
      ssn { '796043735' }
      birls_id { '796043735' }
      participant_id { nil }
      birth_date { '1986-05-06T00:00:00+00:00'.to_date.to_s }
    end

    factory :disabilities_compensation_user, traits: [:loa3] do
      first_name { 'Beyonce' }
      last_name { 'Knowles' }
      gender { 'F' }
      last_signed_in { Time.zone.parse('2017-12-07T00:55:09Z') }
      ssn { '796068949' }
      birls_id { '796068948' }

      transient do
        multifactor { true }
      end
    end

    factory :ch33_dd_user, traits: [:loa3] do
      ssn { '796104437' }
      icn { '82836359962678900' }

      after(:build) do
        allow(BGS.configuration).to receive_messages(env: 'prepbepbenefits', client_ip: '10.247.35.119')
      end
    end

    trait :api_auth_v2 do
      vet360_id { '1' }
      authn_context { LOA::IDME_LOA3_VETS }
      sign_in do
        {
          service_name: SAML::User::AUTHN_CONTEXTS[authn_context][:sign_in][:service_name],
          auth_broker: 'sis',
          client_id: SAML::URLService::MOBILE_CLIENT_ID
        }
      end
      loa do
        {
          current: LOA::THREE,
          highest: LOA::THREE
        }
      end
    end

    trait :api_auth do
      authn_context { LOA::IDME_LOA3_VETS }
      sign_in do
        {
          service_name: SAML::User::AUTHN_CONTEXTS[authn_context][:sign_in][:service_name],
          auth_broker: 'sis',
          client_id: SAML::URLService::MOBILE_CLIENT_ID
        }
      end
      loa do
        {
          current: LOA::THREE,
          highest: LOA::THREE
        }
      end
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
      icn { '1000123456V123456' }
      gender { 'M' }
      birth_date { Faker::Date.between(from: 40.years.ago, to: 10.years.ago) }
      ssn { '796111864' }
      multifactor { true }
      mhv_account_type { 'Premium' }
      va_patient { true }
      cerner_id {}
      cerner_facility_ids { [] }
      vha_facility_ids { %w[358 200MHS] }
      vha_facility_hash { { '358' => %w[998877], '200MHS' => %w[998877] } }
      mhv_ids { %w[12345678901] }
      active_mhv_ids { mhv_ids }

      sign_in do
        {
          service_name: SAML::User::MHV_ORIGINAL_CSID,
          auth_broker: SAML::URLService::BROKER_CODE,
          client_id: SAML::URLService::UNIFIED_SIGN_IN_CLIENTS.first
        }
      end

      loa do
        {
          current: LOA::THREE,
          highest: LOA::THREE
        }
      end
    end

    trait :mhv_not_logged_in do
      mhv_last_signed_in { nil }
    end

    trait :no_vha_facilities do
      vha_facility_ids {}
      vha_facility_hash {}
    end

    trait :with_terms_of_use_agreement do
      after(:build) do |user, _context|
        create(:terms_of_use_agreement, user_account: user.user_account)
      end
    end

    trait :idme_lock do
      user_verification { create(:idme_user_verification, user_account:, idme_uuid:, logingov_uuid:, locked: true) }
    end
  end
end

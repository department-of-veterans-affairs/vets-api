# frozen_string_literal: true

FactoryBot.define do
  factory :iam_user, class: 'IAMUser' do
    uuid { '6260ab13-177f-583d-b2dc-1b350404abb7' }
    last_signed_in { Time.now.utc }
    transient do
      authn_context { LOA::IDME_LOA1_VETS }
      email { 'va.api.user+idme.008@gmail.com' }
      first_name { 'GREG' }
      middle_name { 'A' }
      last_name { 'ANDERSON' }
      gender { 'M' }
      birth_date { '1970-08-12' }
      postal_code { '78665' }
      ssn { '796121200' }
      iam_edipi { '1005079124' }
      iam_sec_id { '0000028114' }
      multifactor { false }

      loa do
        {
          current: LOA::THREE,
          highest: LOA::THREE
        }
      end
    end

    callback(:after_build, :after_stub, :after_create) do |user, _t|
      user_identity = create(:iam_user_identity)
      user.instance_variable_set(:@identity, user_identity)
    end

    trait :no_edipi_id do
      callback(:after_build, :after_stub, :after_create) do |user, _t|
        user_identity = create(:iam_user_identity, iam_edipi: nil)
        user.instance_variable_set(:@identity, user_identity)
      end
    end

    trait :no_birth_date do
      callback(:after_build, :after_stub, :after_create) do |user, _t|
        user_identity = create(:iam_user_identity, birth_date: nil)
        user.instance_variable_set(:@identity, user_identity)
      end
    end

    trait :no_vet360_id do
      callback(:after_build, :after_stub, :after_create) do |user, _t|
        user_identity = create(:iam_user_identity)
        user.instance_variable_set(:@identity, user_identity)
      end
    end

    trait :id_theft_flag do
      callback(:after_build, :after_stub, :after_create) do |user, _t|
        user_identity = create(:iam_user_identity)
        user.instance_variable_set(:@identity, user_identity)
        stub_mpi(build(:mpi_profile, ssn: user_identity.ssn, icn: user_identity.icn, id_theft_flag: true))
      end
    end

    trait :no_multifactor do
      callback(:after_build, :after_stub, :after_create) do |user, _t|
        user_identity = create(:iam_user_identity,
                               multifactor: false,
                               sign_in: { service_name: 'oauth_DSL', auth_broker: SAML::URLService::BROKER_CODE })
        user.instance_variable_set(:@identity, user_identity)
      end
    end

    trait :no_email do
      callback(:after_build, :after_stub, :after_create) do |user, _t|
        user_identity = create(:iam_user_identity, email: nil)
        user.instance_variable_set(:@identity, user_identity)
      end
    end

    trait :logingov do
      callback(:after_build, :after_stub, :after_create) do |user, _t|
        user_identity = create(:iam_user_identity,
                               multifactor: true,
                               sign_in: { service_name: 'oauth_LOGINGOV', auth_broker: SAML::URLService::BROKER_CODE })
        user.instance_variable_set(:@identity, user_identity)
      end
    end

    trait :no_participant_id do
      callback(:after_build, :after_stub, :after_create) do |user, _t|
        user_identity = create(:iam_user_identity)
        user.instance_variable_set(:@identity, user_identity)
      end
    end

    trait :no_vha_facilities do
      callback(:after_build, :after_stub, :after_create) do |user, _t|
        user_identity = create(:iam_user_identity)
        user.instance_variable_set(:@identity, user_identity)
      end
    end

    trait :custom_facility_ids do
      callback(:after_build, :after_stub, :after_create) do |user, _t|
        user_identity = create(:iam_user_identity)
        user.instance_variable_set(:@identity, user_identity)
      end

      transient do
        facility_ids { [] }
        cerner_facility_ids { [] }
      end
    end

    trait :loa2 do
      callback(:after_build, :after_stub, :after_create) do |user, _t|
        user_identity = create(:iam_user_identity, loa: {
                                 current: LOA::TWO,
                                 highest: LOA::TWO
                               })
        user.instance_variable_set(:@identity, user_identity)
      end
    end

    trait :mhv do
      callback(:after_build, :after_stub, :after_create) do |user, _t|
        user_identity = create(:iam_user_identity,
                               mhv_account_type: 'Premium',
                               sign_in: { service_name: 'mhv', auth_broker: SAML::URLService::BROKER_CODE })
        user.instance_variable_set(:@identity, user_identity)
        user.instance_variable_set(:@mhv_account_type, 'Premium')
      end
    end
  end
end

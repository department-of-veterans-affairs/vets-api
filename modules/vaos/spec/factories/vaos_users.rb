# frozen_string_literal: true

FactoryBot.modify do
  factory :user do
    trait :vaos do
      authn_context { 'http://idmanagement.gov/ns/assurance/loa/1/vets' }
      uuid { '3071ca1783954ec19170f3c4bdfd0c95' }
      idme_uuid { SecureRandom.uuid }
      last_signed_in { Time.now.utc }
      mhv_last_signed_in { Time.now.utc }
      email { 'judy.morrison@id.me' }
      first_name { 'Judy' }
      middle_name { 'Snow' }
      last_name { 'Morrison' }
      icn { nil }
      gender { 'F' }
      birth_date { '1953-04-01' }
      ssn { '796061976' }
      va_patient { true }
      should_stub_mpi { false }

      loa do
        {
          current: LOA::THREE,
          highest: LOA::THREE
        }
      end

      after(:build) do |user, _t|
        # build UserVerification & UserAccount records
        create(:idme_user_verification, idme_uuid: user.idme_uuid)
      end
    end

    trait :jac do
      authn_context { 'http://idmanagement.gov/ns/assurance/loa/1/vets' }
      uuid { '3071ca1783954ec19170f3c4bdfd0c95' }
      idme_uuid { SecureRandom.uuid }
      last_signed_in { Time.now.utc }
      mhv_last_signed_in { Time.now.utc }
      email { 'jacqueline.morgan@id.me' }
      first_name { 'Jacqueline' }
      middle_name { 'Kain' }
      last_name { 'Morgan' }
      icn { nil }
      gender { 'F' }
      birth_date { '1962-02-07' }
      ssn { '796029146' }
      va_patient { true }
      should_stub_mpi { false }

      loa do
        {
          current: LOA::THREE,
          highest: LOA::THREE
        }
      end

      after(:build) do |user, _t|
        # build UserVerification & UserAccount records
        create(:idme_user_verification, idme_uuid: user.idme_uuid)
      end
    end
  end
end

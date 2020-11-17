# frozen_string_literal: true

FactoryBot.define do
  factory :iam_user, class: 'IAMUser' do
    uuid { '3097e489-ad75-5746-ab1a-e0aabc1b426a' }
    last_signed_in { Time.now.utc }
    transient do
      authn_context { LOA::IDME_LOA1_VETS }
      email { 'va.api.user+idme.008@gmail.com' }
      first_name { 'GREG' }
      middle_name { 'A' }
      last_name { 'ANDERSON' }
      gender { 'M' }
      birth_date { '1970-08-12' }
      zip { '78665' }
      ssn { '796121200' }
      iam_edipi { '1005079124' }
      iam_icn { '1008596379V859838' }
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

    after(:build) do
      stub_mpi(
        build(
          :mvi_profile,
          edipi: '1005079124',
          birls_id: '796121200',
          participant_id: '796121200',
          birth_date: '1970-08-12T00:00:00+00:00'.to_date.to_s,
          vet360_id: '1'
        )
      )
    end

    trait :no_edipi_id do
      callback(:after_build, :after_stub, :after_create) do |user, _t|
        user_identity = create(:iam_user_identity, iam_edipi: nil)
        user.instance_variable_set(:@identity, user_identity)
      end

      after(:build) do
        stub_mpi(
          build(
            :mvi_profile,
            edipi: nil,
            birls_id: '796121200',
            participant_id: '796121200',
            birth_date: '1970-08-12T00:00:00+00:00'.to_date.to_s,
            vet360_id: '1'
          )
        )
      end
    end
  end
end

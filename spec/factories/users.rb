# frozen_string_literal: true

FactoryBot.define do
  factory :user, class: 'User' do
    uuid 'b2fab2b5-6af0-45e1-a9e2-394347af91ef'
    last_signed_in Time.now.utc

    transient do
      email 'abraham.lincoln@vets.gov'
      first_name 'abraham'
      middle_name nil
      last_name 'lincoln'
      gender 'M'
      birth_date '1809-02-12'
      zip '17325'
      ssn '796111863'
      mhv_icn nil
      multifactor false
      mhv_account_type nil
      va_patient nil

      loa do
        { current: LOA::TWO, highest: LOA::THREE }
      end
    end

    callback(:after_build, :after_stub, :after_create) do |user, t|
      user_identity = create(:user_identity,
                             uuid: user.uuid,
                             email: t.email,
                             first_name: t.first_name,
                             middle_name: t.middle_name,
                             last_name: t.last_name,
                             gender: t.gender,
                             birth_date: t.birth_date,
                             zip: t.zip,
                             ssn: t.ssn,
                             mhv_icn: t.mhv_icn,
                             loa: t.loa,
                             multifactor: t.multifactor,
                             mhv_account_type: t.mhv_account_type)
      user.instance_variable_set(:@identity, user_identity)
    end

    trait :loa1 do
      loa do
        { current: LOA::ONE, highest: LOA::ONE }
      end
    end

    trait :loa3 do
      loa do
        { current: LOA::THREE, highest: LOA::THREE }
      end
    end

    factory :evss_user, traits: [:loa3] do
      first_name('WESLEY')
      last_name('FORD')
      last_signed_in(Time.zone.parse('2017-12-07T00:55:09Z'))
      ssn('796043735')

      after(:build) do
        stub_mvi(
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

    factory :disabilities_compensation_user, traits: [:loa3] do
      first_name('Beyonce')
      last_name('Knowles')
      gender('F')
      last_signed_in(Time.zone.parse('2017-12-07T00:55:09Z'))
      ssn('796068949')

      after(:build) do
        stub_mvi(build(:mvi_profile, birls_id: '796068948'))
      end
    end

    factory :user_with_suffix, traits: [:loa3] do
      first_name('Jack')
      middle_name('Robert')
      last_name('Smith')
      last_signed_in(Time.zone.parse('2017-12-07T00:55:09Z'))
      ssn('796043735')

      after(:build) do
        stub_mvi(
          build(
            :mvi_profile_response,
            edipi: '1007697216',
            birls_id: '796043735',
            participant_id: '600061742',
            birth_date: '1986-05-06T00:00:00+00:00'.to_date.to_s
          )
        )
      end
    end

    trait :mhv_sign_in do
      email 'abraham.lincoln@vets.gov'
      first_name nil
      middle_name nil
      last_name nil
      gender nil
      birth_date nil
      zip nil
      ssn nil
      mhv_icn '12345'
      multifactor false
    end

    trait :mhv do
      uuid 'b2fab2b5-6af0-45e1-a9e2-394347af91ef'
      last_signed_in { Faker::Time.between(2.years.ago, 1.week.ago, :all) }
      mhv_last_signed_in { Faker::Time.between(1.week.ago, 1.minute.ago, :all) }
      email { Faker::Internet.email }
      first_name { Faker::Name.first_name }
      last_name { Faker::Name.last_name }
      gender 'M'
      zip { Faker::Address.postcode }
      birth_date { Faker::Time.between(40.years.ago, 10.years.ago, :all) }
      ssn '796111864'
      multifactor true
      mhv_account_type 'Premium'
      va_patient true

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
            icn: '1000123456V123456',
            mhv_ids: %w[12345678901],
            vha_facility_ids: t.va_patient ? %w[358] : []
          )
        )
      end
    end

    trait :mhv_not_logged_in do
      mhv_last_signed_in nil
    end
  end
end

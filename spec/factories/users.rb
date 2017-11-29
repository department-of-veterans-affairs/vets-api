# frozen_string_literal: true
FactoryBot.define do
  factory :user, class: 'User' do
    uuid 'b2fab2b5-6af0-45e1-a9e2-394347af91ef'
    last_signed_in Time.now.utc

    transient do
      email 'abraham.lincoln@vets.gov'
      first_name 'abraham'
      last_name 'lincoln'
      gender 'M'
      birth_date '1809-02-12'
      zip '17325'
      ssn '796111863'
      mhv_icn nil

      loa do
        { current: LOA::TWO, highest: LOA::THREE }
      end
    end

    callback(:after_build, :after_stub, :after_create) do |user, t|
      user_identity = create(:user_identity,
                             uuid: user.uuid,
                             email: t.email,
                             first_name: t.first_name,
                             last_name: t.last_name,
                             gender: t.gender,
                             birth_date: t.birth_date,
                             zip: t.zip,
                             ssn: t.ssn,
                             mhv_icn: t.mhv_icn,
                             loa: t.loa,
                             )
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

      loa do
        {
          current: LOA::THREE,
          highest: LOA::THREE
        }
      end
    end

    trait :mhv_not_logged_in do
      mhv_last_signed_in nil
    end
  end
end

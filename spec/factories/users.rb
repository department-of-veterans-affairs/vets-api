# frozen_string_literal: true
FactoryGirl.define do
  factory :user, class: 'User' do
    uuid 'b2fab2b5-6af0-45e1-a9e2-394347af91ef'
    email 'abraham.lincoln@vets.gov'
    first_name 'abraham'
    last_name 'lincoln'
    gender 'M'
    birth_date '1809-02-12'
    zip '17325'
    last_signed_in Time.now.utc
    ssn '796111863'
    loa do
      {
        current: LOA::TWO,
        highest: LOA::THREE
      }
    end

    factory :loa1_user do
      loa do
        {
          current: LOA::ONE,
          highest: LOA::ONE
        }
      end
    end

    factory :loa3_user do
      loa do
        {
          current: LOA::THREE,
          highest: LOA::THREE
        }
      end
    end
  end

  factory :mhv_user, class: 'User' do
    uuid 'b2fab2b5-6af0-45e1-a9e2-394347af91ef'
    mhv_last_signed_in { Faker::Time.between(1.week.ago, 1.minute.ago, :all) }
    email { Faker::Internet.email }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    gender 'M'
    zip { Faker::Address.postcode }
    last_signed_in { Faker::Time.between(2.years.ago, 1.week.ago, :all) }
    birth_date { Faker::Time.between(40.years.ago, 10.years.ago, :all) }
    ssn '796111864'
    loa do
      {
        current: LOA::THREE,
        highest: LOA::THREE
      }
    end

    trait :mhv_not_logged_in do
      mhv_last_signed_in nil
    end
  end
end

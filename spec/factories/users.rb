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
    ssn '272111863'
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
    mhv_last_signed_in Time.current
    email 'abraham.lincoln@vets.gov'
    first_name 'abraham'
    last_name 'lincoln'
    gender 'M'
    birth_date Time.new(1809, 2, 12).utc
    ssn '272111864'
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

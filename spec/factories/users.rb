# frozen_string_literal: true
FactoryGirl.define do
  # this factory represents a "typical" LOA 1 user, in that, these
  # are the attributes ID.me will return for LOA 1
  factory :loa1_user, class: 'User' do
    uuid 'b2fab2b5-6af0-45e1-a9e2-394347af91ef'
    email 'abraham.lincoln@vets.gov'
    first_name 'abraham'
    last_name 'lincoln'
    loa_highest LOA::THREE

    # these are the additional attributes returned by ID.me for LOA 3
    factory :loa3_user do
      ssn '272111863'
      zip '17325'
      gender 'M'
      birth_date '1809-02-12'
      last_signed_in Time.now.utc
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
    ssn '272111863'
    loa_highest LOA::THREE
    trait :mhv_not_logged_in do
      mhv_last_signed_in nil
    end
  end
end

# frozen_string_literal: true
FactoryGirl.define do
  factory :user, class: 'User' do
    uuid 'b2fab2b5-6af0-45e1-a9e2-394347af91ef'
    last_signed_in Time.now.utc

    transient do
      loa do
         { current: LOA::TWO, highest: LOA::THREE }
      end
    end

    after(:build) do |user, t|
      user.instance_variable_set(:@identity, build(:user_identity, uuid: user.uuid, loa: t.loa))
    end

    factory :loa1_user do
      transient do
        loa do
           { current: LOA::ONE, highest: LOA::ONE }
        end
      end

      after(:build) do |user, t|
        user.instance_variable_set(:@identity, build(:user_identity, uuid: user.uuid, loa: t.loa))
      end
    end

    factory :loa3_user do
      transient do
        loa do
           { current: LOA::THREE, highest: LOA::THREE }
        end
      end

      after(:build) do |user, t|
        user.instance_variable_set(:@identity, build(:user_identity, uuid: user.uuid, loa: t.loa))
      end
    end
  end

  factory :mhv_user, class: 'User' do
    uuid 'b2fab2b5-6af0-45e1-a9e2-394347af91ef'
    mhv_last_signed_in { Faker::Time.between(1.week.ago, 1.minute.ago, :all) }

    loa do
      {
        current: LOA::THREE,
        highest: LOA::THREE
      }
    end

    trait :mhv_not_logged_in do
      mhv_last_signed_in nil
    end

    after(:build) do |mhv_user, t|
      mhv_user.instance_variable_set(:@identity, build(:mhv_user_identity, uuid: mhv_user.uuid, loa: t.loa))
    end
  end
end

# frozen_string_literal: true

FactoryBot.define do
  factory :vye_award, class: 'Vye::Award' do
    association :user_info, factory: :vye_user_info

    cur_award_ind { Vye::Award.cur_award_inds.values.sample }
    award_begin_date { Faker::Date.between(from: 4.months.ago, to: 3.months.ago) }
    award_end_date { Faker::Date.between(from: 2.months.since, to: 3.months.since) }
    training_time { 40 }
    payment_date { Faker::Date.between(from: 2.months.ago, to: 1.month.ago) }
    monthly_rate { Faker::Number.decimal(l_digits: 4, r_digits: 2) }
    begin_rsn { 'reason' }
    end_rsn { 'reason' }
    type_training { 'type' }
    number_hours { 20 }
    type_hours { 'type' }

    trait :with_verifications do
      after(:create) do |award|
        user_profile = award.user_info.user_profile
        user_info = award.user_info
        create(:vye_verification, user_profile:, user_info:, award:)
      end
    end

    trait :aug_award do
      award_begin_date { Date.new(2024, 7, 23) }
      award_end_date { Date.new(2024, 8, 10) }
    end

    trait :oct_award do
      award_begin_date { Date.new(2024, 8, 11) }
      award_end_date { Date.new(2024, 10, 15) }
    end

    trait :dec_award do
      award_begin_date { Date.new(2024, 10, 16) }
      award_end_date { Date.new(2024, 12, 15) }
    end

    trait :with_specific_verification do
      after(:create) do |award|
        create(
          :vye_verification,
          user_profile: award.user_info.user_profile,
          user_info: award.user_info,
          award: award,
          act_end: award.award_end_date.to_time
        )
      end
    end
  end
end

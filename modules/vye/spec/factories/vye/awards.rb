# frozen_string_literal: true

FactoryBot.define do
  factory :vye_award, class: 'Vye::Award' do
    association :user_info, factory: :vye_user_info

    cur_award_ind { Vye::Award.cur_award_inds.values.sample }
    award_begin_date { Faker::Date.between(from: 4.months.ago, to: 3.months.ago) }
    # award_end_date { Faker::Date.between(from: 2.months.since, to: 3.months.since) }
    # award_end_date { nil }
    training_time { 40 }
    payment_date { Faker::Date.between(from: 2.months.ago, to: 1.month.ago) }
    monthly_rate { Faker::Number.decimal(l_digits: 4, r_digits: 2) }
    begin_rsn { 'reason' }
    end_rsn { 'reason' }
    type_training { 'type' }
    number_hours { 20 }
    type_hours { 'type' }

    trait :cur_award do
      cur_award_ind { 'C' }
    end

    # rubocop:disable Naming/VariableNumber
    trait :begin_mar_9_2024 do
      award_begin_date { '2024-03-09' }
    end

    trait :begin_mar_11_2024 do
      award_begin_date { '2024-03-11' }
    end

    trait :begin_aug_19_2024 do
      award_begin_date { '2024-08-19' }
    end

    trait :begin_oct_1_2024 do
      award_begin_date { '2024-10-01' }
    end

    trait :begin_oct_12_2024 do
      award_begin_date { '2024-10-12' }
    end

    trait :no_award_end_date do
      award_end_date { nil }
    end

    trait :end_may_10_2024 do
      award_end_date { '2024-05-10' }
    end

    trait :end_dec_13_2024 do
      award_end_date { '2024-12-13' }
    end

    trait :b_training_type do
      type_training { 'B' }
    end

    trait :quarter_training_time do
      training_time { 10 }
    end

    trait :monthly_rate_166 do
      monthly_rate { 166.50 }
    end

    trait :monthly_rate_666 do
      monthly_rate { 666.00 }
    end

    trait :monthly_rate_681 do
      monthly_rate { 681.00 }
    end

    trait :type_hours_s03 do
      type_hours { 'S03' }
    end

    trait :type_hours_s12 do
      type_hours { 'S12' }
    end

    trait :type_hours_s14 do
      type_hours { 'S14' }
    end

    trait :type_hours_s17 do
      type_hours { 'S17' }
    end

    trait :payment_date_oct_1_2024 do
      payment_date { '2024-10-01' }
    end

    trait :with_verifications do
      after(:create) do |award|
        user_profile = award.user_info.user_profile
        user_info = award.user_info
        create(:vye_verification, user_profile:, user_info:, award:)
      end
    end

    trait :with_verification_paid_dt_2024_10_1 do
      after(:create) do |award|
        user_profile = award.user_info.user_profile
        user_info = award.user_info
        create(:vye_verification, :last_paid_oct_1_2024, user_profile:, user_info:, award:)
      end
    end
    # rubocop:enable Naming/VariableNumber
  end
end

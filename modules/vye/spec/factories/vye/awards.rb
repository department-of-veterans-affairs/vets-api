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
  end
end

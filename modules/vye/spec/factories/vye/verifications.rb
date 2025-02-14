# frozen_string_literal: true

FactoryBot.define do
  factory :vye_verification, class: 'Vye::Verification' do
    association :user_profile, factory: :vye_user_profile
    association :award, factory: :vye_award

    transact_date { Time.zone.now }
    source_ind { 'W' }

    # needs to be older than 5 years which will include a leap year
    # (unless it spans a turn of the century in which case it will still meet the criteria)
    # 5 * 365 = 1825 + 1 leap day plus another 2 days to be older than 5 years
    trait :stale do
      created_at { 1828.days.ago }
    end
    # rubocop:disable Naming/VariableNumber
    trait :last_paid_oct_1_2024 do
      payment_date { '2024-10-01' }
    end

    trait :transact_date_oct_1_2024 do
      transact_date { '2024-10-1' }
    end
    # rubocop:enable Naming/VariableNumber
  end
end

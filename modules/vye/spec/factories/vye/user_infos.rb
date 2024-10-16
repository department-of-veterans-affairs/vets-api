# frozen_string_literal: true

FactoryBot.define do
  digit = proc { rand(0..9).to_s }

  factory :vye_user_info, class: 'Vye::UserInfo' do
    association :bdn_clone, factory: :vye_bdn_clone
    association :user_profile, factory: :vye_user_profile

    file_number { (1..9).map(&digit).join }
    dob { Faker::Date.birthday }
    stub_nm { format("#{Faker::Name.first_name[0, 1].upcase} #{Faker::Name.last_name[0, 3].upcase}") }
    mr_status { 'A' }
    rem_ent do
      months = (36 * rand).floor
      days = (rand * 100_000).floor
      format('%02<months>u%05<days>u', months:, days:)
    end
    cert_issue_date { Faker::Date.between(from: 10.years.ago, to: 2.years.ago) }
    del_date { Faker::Date.between(from: 4.months.since, to: 2.years.since) }
    date_last_certified { Faker::Date.between(from: 3.months.ago, to: 5.days.ago) }
    rpo_code { Faker::Number.number(digits: 4) }
    fac_code { Faker::Lorem.word }
    payment_amt { Faker::Number.decimal(l_digits: 4, r_digits: 2) }
    indicator { 'A' }
    bdn_clone_active { true }

    after(:create) do |user_info|
      create_list(:vye_address_backend, 1, user_info:)
    end

    trait :with_address_changes do
      after(:create) do |user_info|
        create_list(:vye_address_change, 2, user_info:, origin: 'frontend')
      end
    end

    trait :with_verified_awards do
      after(:create) do |user_info|
        create_list(:vye_award, 4, :with_verifications, user_info:)
      end
    end

    trait :with_direct_deposit_changes do
      after(:create) do |user_info|
        create_list(:vye_direct_deposit_change, 2, user_info:)
      end
    end
  end

  factory :vye_user_info_td_number, class: 'Vye::UserInfo' do
    association :bdn_clone, factory: :vye_bdn_clone
    association :user_profile, factory: :vye_user_profile_td_number

    file_number { (1..9).map(&digit).join }
    dob { Faker::Date.birthday }
    stub_nm { format("#{Faker::Name.first_name[0, 1].upcase} #{Faker::Name.last_name[0, 3].upcase}") }
    mr_status { 'A' }
    rem_ent do
      months = (36 * rand).floor
      days = (rand * 100_000).floor
      format('%02<months>u%05<days>u', months:, days:)
    end
    cert_issue_date { Faker::Date.between(from: 10.years.ago, to: 2.years.ago) }
    del_date { Faker::Date.between(from: 4.months.since, to: 2.years.since) }
    date_last_certified { Faker::Date.between(from: 3.months.ago, to: 5.days.ago) }
    rpo_code { Faker::Number.number(digits: 4) }
    fac_code { Faker::Lorem.word }
    payment_amt { Faker::Number.decimal(l_digits: 4, r_digits: 2) }
    indicator { 'A' }
    bdn_clone_active { true }
  end
end

# frozen_string_literal: true

FactoryBot.define do
  digit = proc { rand(0..9).to_s }

  factory :vye_user_info, class: 'Vye::UserInfo' do
    association :bdn_clone, factory: :vye_bdn_clone
    association :user_profile, factory: :vye_user_profile

    file_number { (1..9).map(&digit).join }
    dob { Faker::Date.birthday }
    stub_nm { Faker::Name.name }
    mr_status { Vye::UserInfo.mr_statuses.values.sample }
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
    indicator { Vye::UserInfo.indicators.values.sample }
    bdn_clone_active { true }
  end
end

# frozen_string_literal: true

FactoryBot.define do
  factory :vye_user_info, class: 'Vye::UserInfo' do
    Faker::Number.number(digits: 9).tap do |v|
      v = v.to_s
      ssn { v }
      file_number { v }
    end
    suffix { Faker::Name.suffix }
    full_name { Faker::Name.name }
    address_line2 { Faker::Address.secondary_address }
    address_line3 { Faker::Address.community }
    address_line4 { Faker::Address.city }
    address_line5 { Faker::Address.state }
    address_line6 { Faker::Address.zip }
    zip { Faker::Address.zip }
    dob { Faker::Date.birthday }
    stub_nm { Faker::Name.name }
    mr_status { Faker::Lorem.word }
    rem_ent { Faker::Lorem.word }
    cert_issue_date { Faker::Date.between(from: 10.years.ago, to: Time.zone.today) }
    del_date { Faker::Date.between(from: 10.years.ago, to: Time.zone.today) }
    date_last_certified { Faker::Date.between(from: 10.years.ago, to: Time.zone.today) }
    rpo_code { Faker::Number.number(digits: 4) }
    fac_code { Faker::Lorem.word }
    payment_amt { Faker::Number.decimal(l_digits: 4, r_digits: 2) }
    indicator { Vye::UserInfo.indicators.values.sample }
  end
end

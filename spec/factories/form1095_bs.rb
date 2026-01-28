# frozen_string_literal: true

FactoryBot.define do
  factory :form1095_b do
    veteran_icn { '3456787654324567' }
    tax_year { 2021 }
    form_data {
      {
        first_name: 'John',
        middle_name: 'Michael',
        last_name: 'Smith',
        last_4_ssn: '1234',
        address: '123 Test st',
        city: 'Hollywood',
        state: 'CA',
        zip_code: '12345',
        country: 'USA',
        is_beneficiary: false,
        is_corrected: false,
        coverage_months: Array.new(13, true)
      }.to_json
    }
  end

  factory :enrollment_system_form1095_b, class: 'VeteranEnrollmentSystem::Form1095B::Form1095B' do
    tax_year { 2024 }
    first_name { 'John' }
    middle_name { 'Michael' }
    last_name { 'Smith' }
    last_4_ssn { '1234' }
    birth_date { '1932-02-05'.to_date }
    address { '123 Test st' }
    city { 'Hollywood' }
    state { 'CA' }
    province { nil }
    zip_code { '12345' }
    foreign_zip { '12345' }
    country { 'USA' }
    is_corrected { false }
    coverage_months { Array.new(13, true) }
  end
end

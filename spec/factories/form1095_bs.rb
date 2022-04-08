# frozen_string_literal: true

FactoryBot.define do
  factory :form1095_b do
    veteran_icn { '3456787654324567' }
    tax_year { 2021 }
    form_data {
      {
        first_name: 'First',
        middle_name: 'Middle',
        last_name: 'Last',
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
end

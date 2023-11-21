# frozen_string_literal: true

FactoryBot.define do
  factory :std_income_threshold_0_variant, class: 'StdIncomeThreshold' do
    id { 1_115_983 }
    version { 0 }
    created { 'Tue, 16 Oct 2007 123844.000000000 UTC +0000' }
    income_threshold_year { 2018 }
    exempt_amount { 33_632 }
    medical_expense_deductible { 5 }
    child_income_exclusion { 12_200 }
    dependent { 40_359 }
    add_dependent_threshold { 2313 }
    property_threshold { 80_000 }
    pension_threshold { 13_535 }
    pension_1_dependent { 17_724 }
    add_dependent_pension { 2313 }
    ninety_day_hospital_copay { 1 }
    add_ninety_day_hospital_copay { 682 }
    outpatient_basic_care_copay { 15 }
    outpatient_specialty_copay { 50 }
    threshold_effective_date { 'Sun, 01 May 0044 000000.000000000 UTC +0000' }
    aid_and_attendance_threshold { 22_577 }
    outpatient_preventive_copay { 0 }
    medication_copay { 8 }
    medication_copay_annual_cap { nil }
    ltc_inpatient_copay { 97 }
    ltc_outpatient_copay { 15 }
    ltc_domiciliary_copay { 5 }
    inpatient_per_diem { 10 }
  end

  factory :gmt_threshold_0_variant, class: 'GmtThreshold' do
    id { 1_115_983 }
    version { 0 }
    created { 'Tue, 16 Oct 2007 123844.000000000 UTC +0000' }
    effective_year { 2020 }
    state_name { 'Massachusetts' }
    county_name { 'Hampden County' }
    fips { 25_013 }
    trhd1 { 45_200 }
    trhd2 { 51_650 }
    trhd3 { 58_100 }
    trhd4 { 64_550 }
    trhd5 { 69_750 }
    trhd6 { 74_900 }
    trhd7 { 80_050 }
    trhd8 { 85_250 }
    msa { 8000 }
  end

  factory :std_county_0_variant, class: 'StdCounty' do
    id { 1_115_983 }
    version { 0 }
    created { 'Tue, 16 Oct 2007 12:38:44.000000000 UTC +00:00' }
    name { 'Hampden' }
    county_number { 13 }
    description { 'The county of Hampden' }
    state_id { 1_009_325 }
  end

  factory :std_state_0_variant, class: 'StdState' do
    id { 1_115_983 }
    version { 0 }
    created { 'Tue, 16 Oct 2007 12:38:44.000000000 UTC +00:00' }
    name { 'Massachusetts' }
    postal_name { 'MA' }
    fips_code { 25 }
    country_id { 1_006_840 }
  end

  factory :std_zipcode_0_variant, class: 'StdZipcode' do
    id { 1_115_984 }
    version { 0 }
    created { 'Tue, 16 Oct 2007 12:38:44.000000000 UTC +00:00' }
    zip_code { '01020' }
    state_id { 1_009_325 }
    county_number { 13 }
  end
end

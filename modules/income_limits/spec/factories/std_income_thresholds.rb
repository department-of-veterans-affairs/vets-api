# frozen_string_literal: true

FactoryBot.define do
  factory :std_income_threshold do
    id { 1_115_983 }
    version { 0 }
    created { 'Tue, 16 Oct 2007 123844.000000000 UTC +0000' }
    income_threshold_year { 2020 }
    exempt_amount { 34_616 }
    medical_expense_deductible { 5 }
    child_income_exclusion { 12_550 }
    dependent { 41_539 }
    add_dependent_threshold { 2382 }
    property_threshold { 80_000 }
    pension_threshold { 13_931 }
    pension_1_dependent { 18_243 }
    add_dependent_pension { 2382 }
    ninety_day_hospital_copay { 1 }
    add_ninety_day_hospital_copay { 742 }
    outpatient_basic_care_copay { 15 }
    outpatient_specialty_copay { 50 }
    threshold_effective_date { 'Sun, 01 May 0044 000000.000000000 UTC +0000' }
    aid_and_attendance_threshold { 23_238 }
    outpatient_preventive_copay { 0 }
    medication_copay { 8 }
    medication_copay_annual_cap { nil }
    ltc_inpatient_copay { 97 }
    ltc_outpatient_copay { 15 }
    ltc_domiciliary_copay { 5 }
    inpatient_per_diem { 10 }
  end
end

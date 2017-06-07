# frozen_string_literal: true
FactoryGirl.define do
  factory :education_enrollment_status, class: 'EducationEnrollmentStatus' do
    va_file_number '1234-56-7890'
    regional_processing_office 'Central Office, Washington DC'
    eligibility_date '2015-02-02'
    delimiting_date '2019-02-02'
    percentage_benefit 100
    original_entitlement_days 100
    used_entitlement_days 75
    remaining_entitlement_days 25
    facilities [{ begin_date: '2015-03-03', name: 'Harrisburg Area Community College' }]
  end
end

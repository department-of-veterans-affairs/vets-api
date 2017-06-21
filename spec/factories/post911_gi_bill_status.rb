# frozen_string_literal: true
FactoryGirl.define do
  factory :post911_gi_bill_status, class: 'EVSS::GiBillStatus::Post911GIBillStatus' do
    first_name 'Thomas'
    last_name 'Anderson'
    name_suffix ''
    date_of_birth '05-05-1980'
    va_file_number '1234-56-7890'
    regional_processing_office 'Central Office, Washington DC'
    eligibility_date '2015-02-02'
    delimiting_date '2019-02-02'
    percentage_benefit 100
    original_entitlement 100
    used_entitlement 75
    remaining_entitlement 25
    # TODO: enrollments and amendments should be their own factories
    enrollments [{
      begin_date: '2015-03-03',
      end_date: '2016-03-03',
      facility_name: 'Harrisburg Area Community College',
      amendments: [{ type: 'some amendment type' }]
    }]
  end
end

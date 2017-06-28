# frozen_string_literal: true
FactoryGirl.define do
  factory :veteran_input, class: Preneeds::VeteranInput do
    gender 'Male'
    is_deceased 'unsure'
    marital_status 'Married'
    military_service_number '123456789'
    ssn '123-45-6789'
    va_claim_number '123456789'
    military_status 'A'

    current_name { attributes_for :name_input }
    service_name { attributes_for :name_input }
    address { attributes_for :address_input }
    service_records { [attributes_for(:service_record_input)] }
  end
end

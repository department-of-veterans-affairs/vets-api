# frozen_string_literal: true
FactoryGirl.define do
  factory :veteran, class: Preneeds::Veteran do
    gender 'Male'
    is_deceased 'unsure'
    marital_status 'Married'
    military_service_number '123456789'
    ssn '123-45-6789'
    va_claim_number '123456789'
    military_status 'A'

    current_name { attributes_for :name }
    service_name { attributes_for :name }
    address { attributes_for :address }
    service_records { [attributes_for(:service_record)] }
  end
end

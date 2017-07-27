# frozen_string_literal: true
FactoryGirl.define do
  factory :veteran, class: Preneeds::Veteran do
    date_of_birth '2001-01-31T10:00:00'
    date_of_death '2001-01-31T10:00:00'
    gender 'Male'
    is_deceased 'unsure'
    marital_status 'Married'
    military_service_number '123456789'
    place_of_birth 'Brooklyn, NY'
    ssn '123-45-6789'
    va_claim_number '123456789'
    military_status ['A']

    current_name { attributes_for :name }
    service_name { attributes_for :name }
    address { attributes_for :address }
    service_records { [attributes_for(:service_record)] }
  end
end

# frozen_string_literal: true

FactoryBot.define do
  factory :veteran, class: 'Preneeds::Veteran' do
    date_of_birth { '2001-01-31' }
    date_of_death { '2001-01-31' }
    gender { 'Male' }
    is_deceased { 'unsure' }
    marital_status { 'Married' }
    military_service_number { '123456789' }
    place_of_birth { 'Brooklyn, NY' }
    ssn { '123456789' }
    va_claim_number { '23456789' }
    military_status { 'A' }
    race { attributes_for(:race) }

    current_name { attributes_for(:full_name) }
    service_name { attributes_for(:full_name) }
    address { attributes_for(:address) }
    service_records { [attributes_for(:service_record)] }
  end

  factory :veteran_foreign_address, parent: :veteran do
    address { attributes_for(:foreign_address) }
  end
end

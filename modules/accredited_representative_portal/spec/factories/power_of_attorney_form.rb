# frozen_string_literal: true

form_data = <<~JSON
  {
    "authorizations": {
      "record_disclosure": true,
      "record_disclosure_limitations": [],
      "address_change": true
    },
    "dependent": {
      "name": {
        "first": "John",
        "middle": "Middle",
        "last": "Doe"
      },
      "address": {
        "address_line1": "123 Main St",
        "address_line2": "Apt 1",
        "city": "Springfield",
        "state_code": "IL",
        "country": "US",
        "zip_code": "62704",
        "zip_code_suffix": "6789"
      },
      "date_of_birth": "1980-12-31",
      "relationship": "Spouse",
      "phone": "1234567890",
      "email": "veteran@example.com"
    },
    "veteran": {
      "name": {
        "first": "John",
        "middle": "Middle",
        "last": "Doe"
      },
      "address": {
        "address_line1": "123 Main St",
        "address_line2": "Apt 1",
        "city": "Springfield",
        "state_code": "IL",
        "country": "US",
        "zip_code": "62704",
        "zip_code_suffix": "6789"
      },
      "ssn": "123456789",
      "va_file_number": "123456789",
      "date_of_birth": "1980-12-31",
      "service_number": "123456789",
      "service_branch": "ARMY",
      "phone": "1234567890",
      "email": "veteran@example.com"
    }
  }
JSON

FactoryBot.define do
  factory :power_of_attorney_form, class: 'AccreditedRepresentativePortal::PowerOfAttorneyForm' do
    data { form_data }
  end
end

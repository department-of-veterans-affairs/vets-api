# frozen_string_literal: true

FactoryBot.define do
  factory :veteran_readiness_employment_claim, class: 'SavedClaim::VeteranReadinessEmploymentClaim' do
    form_id { '28-1900' }

    transient do
      regional_office { '317 - St. Petersburg' }
      country { 'USA' }
      first { 'Homer' }
    end

    form {
      {
        'useEva' => true,
        'useTelecounseling' => true,
        'appointmentTimePreferences' => {
          'morning' => true,
          'midDay' => true,
          'afternoon' => false
        },
        'yearsOfEducation' => '17',
        'isMoving' => true,
        'newAddress' => {
          'country' => country,
          'street' => '1019 Robin Cir',
          'city' => 'Arroyo Grande',
          'state' => 'CA',
          'postalCode' => '93420'
        },
        'veteranAddress' => {
          'country' => country,
          'street' => '9417 Princess Palm',
          'city' => 'Tampa',
          'state' => 'FL',
          'postalCode' => '33928'
        },
        'mainPhone' => '5555555555',
        'email' => 'test@gmail.xom',
        'veteranInformation' => {
          'fullName' => {
            'first' => first,
            'middle' => 'John',
            'last' => 'Simpson'
          },
          'dob' => '1998-01-02',
          'pid' => '600036503',
          'edipi' => '1005354478',
          'vet360ID' => nil,
          'regionalOffice' => regional_office
        }
      }.to_json
    }
  end

  factory :new_veteran_readiness_employment_claim, class: 'SavedClaim::VeteranReadinessEmploymentClaim' do
    form_id { '28-1900-V2' }

    transient do
      main_phone { '2222222222' }
      cell_phone { '3333333333' }
      international_number { '+4444444444' }
      email { 'email@test.com' }
      is_moving { true }
      years_of_ed { '10' }
      country { 'USA' }
      postal_code { '10001' }
      first { 'First' }
      middle { 'Middle' }
      last { 'Last' }
      dob { '1980-01-01' }
      privacyStatementAcknowledged { true }
    end

    form {
      {
        'mainPhone' => main_phone,
        'cellPhone' => cell_phone,
        'internationalNumber' => international_number,
        'email' => email,
        'newAddress' => {
          'country' => country,
          'street' => '13 usa street',
          'city' => 'New York',
          'state' => 'NY',
          'postalCode' => postal_code
        },
        'isMoving' => is_moving,
        'veteranAddress' => {
          'country' => country,
          'street' => '12 usa street',
          'city' => 'New York',
          'state' => 'NY',
          'postalCode' => postal_code
        },
        'yearsOfEducation' => years_of_ed,
        'veteranInformation' => {
          'fullName' => {
            'first' => first,
            'middle' => middle,
            'last' => last,
            'suffix' => 'III'
          },
          'dob' => dob
        },
        'privacyStatementAcknowledged' => privacyStatementAcknowledged
      }.to_json
    }
  end

  factory :new_veteran_readiness_employment_claim_minimal, class: 'SavedClaim::VeteranReadinessEmploymentClaim' do
    form_id { '28-1900-V2' }

    form {
      {
        'email' => 'email@test.com',
        'isMoving' => false,
        'yearsOfEducation' => '10',
        'veteranInformation' => {
          'fullName' => {
            'first' => 'First',
            'last' => 'Last'
          },
          'dob' => '1980-01-01'
        },
        'privacyStatementAcknowledged' => true
      }.to_json
    }
  end
end

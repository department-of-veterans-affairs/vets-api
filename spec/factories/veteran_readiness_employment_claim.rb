# frozen_string_literal: true

FactoryBot.define do
  factory :veteran_readiness_employment_claim, class: 'SavedClaim::VeteranReadinessEmploymentClaim' do
    form_id { '28-1900' }

    transient do
      regional_office { '317 - St. Petersburg' }
      country { 'USA' }
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
            'first' => 'Homer',
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
    form_id { '28-1900' }

    form {
      {
        'mainPhone' => '2222222222',
        'cellPhone' => '3333333333',
        'internationalNumber' => '+4444444444',
        'email' => 'email@test.com',
        'newAddress' => {
          'country' => 'USA',
          'street' => '13 usa street',
          'city' => 'New York',
          'state' => 'NY',
          'postalCode' => '10001'
        },
        'isMoving' => true,
        'veteranAddress' => {
          'country' => 'USA',
          'street' => '12 usa street',
          'city' => 'New York',
          'state' => 'NY',
          'postalCode' => '10001'
        },
        'yearsOfEducation' => '10',
        'veteranInformation' => {
          'fullName' => {
            'first' => 'First',
            'middle' => 'Middle',
            'last' => 'Last',
            'suffix' => 'III'
          },
          'dob' => '1980-01-01'
        }
      }.to_json
    }
  end
end

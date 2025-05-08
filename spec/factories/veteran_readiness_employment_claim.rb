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
end

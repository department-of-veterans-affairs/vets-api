# frozen_string_literal: true

FactoryBot.define do
  factory :veteran_readiness_employment_claim, class: SavedClaim::VeteranReadinessEmploymentClaim do
    form_id { '28-1900' }

    form {
      {
        'useEva' => true,
        'useTelecounseling' => true,
        'appointmentTimePreferences' => {
          'morning' => true,
          'midDay' => true,
          'afternoon' => false
        },
        'yearsOfEducation' => '2',
        'isMoving' => true,
        'newAddress' => {
          'country' => 'USA',
          'street' => '1019 Robin Cir',
          'city' => 'Arroyo Grande',
          'state' => 'CA',
          'postalCode' => '93420'
        },
        'veteranAddress' => {
          'country' => 'USA',
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
          'ssn' => '987456457',
          'dob' => '1998-01-02',
          'VAFileNumber' => '88776655',
          'pid' => '600036503',
          'edipi' => '1005354478',
          'vet360ID' => nil,
          'regionalOffice' => '317 - St. Petersburg'
        }
      }.to_json
    }
  end
end

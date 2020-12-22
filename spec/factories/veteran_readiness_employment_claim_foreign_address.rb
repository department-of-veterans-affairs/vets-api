# frozen_string_literal: true

FactoryBot.define do
  factory :veteran_readiness_employment_claim_foreign_address, class: SavedClaim::VeteranReadinessEmploymentClaim do
    form_id { '28-1900' }

    form {
      {
        'useEva' => true,
        'useTelecounseling' => true,
        'appointmentTimePreferences' => {
          'morning' => true,
          'midDay' => true,
          'afternoon' => false,
          'other' => false
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
          'dob' => '1998-01-02'
        }
      }.to_json
    }
  end
end

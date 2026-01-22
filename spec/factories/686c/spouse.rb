# frozen_string_literal: true

FactoryBot.define do
  factory :spouse_v2, class: 'BGSDependents::Spouse' do
    initialize_with do
      {
        'view:selectable686_options' => {
          'add_spouse' => true
        },
        'dependents_application' => {
          'household_income' => true,
          'current_marriage_information' => {
            'type_of_marriage' => 'OTHER',
            'type_other' => 'Some Other Thing',
            'location' => {
              'city' => 'Slawson',
              'state' => 'CA'
            },
            'date' => '2014-03-04'
          },
          'does_live_with_spouse' => {
            'spouse_income' => true,
            'spouse_does_live_with_veteran' => true
          },
          'spouse_information' => {
            'va_file_number' => '00000000',
            'service_number' => '11111111',
            'ssn' => '323454323',
            'birth_date' => '1981-04-04',
            'is_veteran' => true,
            'full_name' => {
              'first' => 'Jenny',
              'middle' => 'Lauren',
              'last' => 'McCarthy',
              'suffix' => 'Sr.'
            }
          },
          'veteran_contact_information' => {
            'phone_number' => '5555555555',
            'international_phone_number' => '5555555556',
            'email_address' => 'test@test.com',
            'electronic_correspondence' => true,
            'veteran_address' => {
              'country' => 'USA',
              'street' => '8200 Doby LN',
              'city' => 'Pasadena',
              'state' => 'CA',
              'postal_code' => '21122'
            }
          },
          'veteran_information' => {
            'birth_date' => '1809-02-12',
            'full_name' => {
              'first' => 'Wesley',
              'last' => 'Ford',
              'middle' => nil
            },
            'ssn' => '987654321',
            'va_file_number' => '987654321'
          },
          'days_till_expires' => 365,
          'privacy_agreement_accepted' => true
        },
        'veteran_information' => {
          'birth_date' => '1809-02-12',
          'full_name' => {
            'first' => 'Wesley',
            'last' => 'Ford',
            'middle' => nil
          },
          'ssn' => '987654321',
          'va_file_number' => '987654321'
        }
      }
    end
  end
end

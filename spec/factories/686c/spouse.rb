# frozen_string_literal: true

FactoryBot.define do
  factory :spouse, class: 'BGSDependents::Spouse' do
    initialize_with do
      {
        'view:selectable686_options' => {
          'add_spouse' => true
        },
        'dependents_application' => {
          'veteran_contact_information' => {
            'veteran_address' => {
              'country_name' => 'USA',
              'address_line1' => '8200 Doby LN',
              'city' => 'Pasadena',
              'state_code' => 'CA',
              'zip_code' => '21122'
            },
            'phone_number' => '1112223333',
            'email_address' => 'foo@foo.com'
          },
          'does_live_with_spouse' => {
            'spouse_does_live_with_veteran' => true
          },
          'spouse_information' => {
            'full_name' => {
              'first' => 'Jenny',
              'middle' => 'Lauren',
              'last' => 'McCarthy',
              'suffix' => 'Sr.'
            },
            'ssn' => '323454323',
            'birth_date' => '1981-04-04',
            'is_veteran' => true,
            'va_file_number' => '00000000',
            'service_number' => '11111111'
          },
          'current_marriage_information' => {
            'date' => '2014-03-04',
            'location' => {
              'state' => 'CA',
              'city' => 'Slawson'
            },
            'type' => 'OTHER',
            'type_other' => 'Some Other Thing'
          }
        }
      }
    end
  end
end

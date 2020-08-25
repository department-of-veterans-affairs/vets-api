# frozen_string_literal: true

FactoryBot.define do
  factory :adopted_child_lives_with_veteran, class: Hash do
    initialize_with do
      {
        'view:selectable686_options' => {
          'add_child' => true
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
          'children_to_add' => [
            {
              'does_child_live_with_you' => true,
              'place_of_birth' => {
                'state' => 'CA',
                'city' => 'Slawson'
              },
              'child_status' => {
                'adopted' => true
              },
              'previously_married' => 'No',
              'full_name' => {
                'first' => 'Adopted first name',
                'middle' => 'adopted middle name',
                'last' => 'adopted last name',
                'suffix' => 'Sr.'
              },
              'ssn' => '370947143',
              'birth_date' => '2010-03-03'
            }
          ]
        }
      }
    end
  end
end

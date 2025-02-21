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

  factory :adopted_child_lives_with_veteran_v2, class: Hash do
    initialize_with do
      {
        'view:selectable686_options' => {
          'add_child' => true
        },
        'dependents_application' => {
          'household_income' => true,
          'veteran_contact_information' => {
            'phone_number' => '1112223333',
            'international_phone_number' => '1112223333',
            'email_address' => 'foo@foo.com',
            'electronic_correspondence' => true,
            'veteran_address' => {
              'country' => 'USA',
              'street' => '8200 Doby LN',
              'city' => 'Pasadena',
              'state' => 'CA',
              'postal_code' => '21122'
            }
          },
          'children_to_add' => [{
            'income_in_last_year' => false,
            'does_child_live_with_you' => true,
            'has_child_ever_been_married' => false,
            'relationship_to_child' => { 'adopted' => true },
            'birth_location' => {
              'location' => {
                'state' => 'CA',
                'city' => 'Slawson',
                'postal_code' => '90043'
              }
            },
            'ssn' => '370947143',
            'full_name' => {
              'first' => 'Adopted first name',
              'middle' => 'adopted middle name',
              'last' => 'adopted last name',
              'suffix' => 'Sr.'
            },
            'birth_date' => '2010-03-03'
          }],
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
          'use_v2' => true,
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

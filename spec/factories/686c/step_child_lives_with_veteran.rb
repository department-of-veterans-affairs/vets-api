# frozen_string_literal: true

FactoryBot.define do
  factory :step_child_lives_with_veteran, class: Hash do
    initialize_with do
      {
        'view:selectable686_options' => {
          'add_child' => true
        },
        'dependents_application' => {
          'children_to_add' => [
            {
              'does_child_live_with_you' => true,
              'place_of_birth' => {
                'is_outside_us' => false,
                'state' => 'AZ',
                'city' => 'Sedona'
              },
              'child_status' => {
                'stepchild' => true,
                'date_became_dependent' => '2021-09-02',
                'stepchild_parent' => {
                  'first' => 'Patricia',
                  'last' => 'StepParent'
                },
                'ssn' => '333224444',
                'birth_date' => '1988-06-12'
              },
              'not_self_sufficient' => true,
              'previously_married' => 'No',
              'full_name' => {
                'first' => 'Pol',
                'last' => 'Testerman'
              },
              'ssn' => '333224444',
              'birth_date' => '2021-02-16'
            }
          ],
          'veteran_contact_information' => {
            'veteran_address' => {
              'country_name' => 'USA',
              'address_line1' => 'One E 161 St',
              'city' => 'Bronx',
              'state_code' => 'NY',
              'zip_code' => '10451'
            },
            'phone_number' => '6469778000',
            'email_address' => 'tester@test.com'
          }
        }
      }
    end
  end

  factory :step_child_lives_with_veteran_v2, class: Hash do
    initialize_with do
      {
        'view:selectable686_options' => {
          'add_child' => true
        },
        'dependents_application' => {
          'household_income' => true,
          'veteran_contact_information' => {
            'phone_number' => '6469778000',
            'international_phone_number' => '6469778000',
            'email_address' => 'test@test.com',
            'electronic_correspondence' => true,
            'veteran_address' => {
              'country' => 'USA',
              'street' => 'One E 161 St',
              'city' => 'Bronx',
              'state' => 'NY',
              'postal_code' => '10451'
            }
          },
          'children_to_add' => [{
            'income_in_last_year' => false,
            'does_child_live_with_you' => true,
            'has_child_ever_been_married' => false,
            'relationship_to_child' => { 'stepchild' => true },
            'birth_location' => { 'location' => { 'state' => 'AZ', 'city' => 'Sedona', 'postal_code' => '86336' } },
            'ssn' => '333224444',
            'date_entered_household' => '2021-09-02',
            'biological_parent_name' => { 'first' => 'Patricia', 'last' => 'StepParent' },
            'biological_parent_ssn' => '987654321',
            'biological_parent_dob' => '1988-06-12',
            'full_name' => {
              'first' => 'pol',
              'last' => 'testerman'
            },
            'birth_date' => '2021-02-16'
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

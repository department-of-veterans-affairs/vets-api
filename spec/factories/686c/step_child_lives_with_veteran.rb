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
end

# frozen_string_literal: true

FactoryBot.define do
  factory :form_674_only, class: Hash do
    initialize_with do
      {
        'view:selectable686_options' => {
          'report674' => true
        },
        'dependents_application' => {
          'student_does_have_networth' => true,
          'student_networth_information' => {
            'savings' => '3455',
            'securities' => '3234',
            'real_estate' => '5623',
            'other_assets' => '4566',
            'remarks' => 'Some remarks about the student\'s net worth'
          },
          'student_does_earn_income' => true,
          'student_earnings_from_school_year' => {
            'earnings_from_all_employment' => '12000',
            'annual_social_security_payments' => '3453',
            'other_annuities_income' => '30595',
            'all_other_income' => '5596'
          },
          'student_will_earn_income_next_year' => true,
          'student_expected_earnings_next_year' => {
            'earnings_from_all_employment' => '12000',
            'annual_social_security_payments' => '3940',
            'other_annuities_income' => '3989',
            'all_other_income' => '984'
          },
          'student_did_attend_school_last_term' => true,
          'last_term_school_information' => {
            'name' => 'Another Amazing School',
            'address' => {
              'country_name' => 'USA',
              'address_line1' => '2037 29th St',
              'city' => 'Rock Island',
              'state_code' => 'IL',
              'zip_code' => '61201'
            },
            'term_begin' => '2016-03-04',
            'date_term_ended' => '2017-04-05',
            'classes_per_week' => 4,
            'hours_per_week' => 40
          },
          'current_term_dates' => {
            'official_school_start_date' => '2019-03-03',
            'expected_student_start_date' => '2019-03-05',
            'expected_graduation_date' => '2023-03-03'
          },
          'program_information' => {
            'student_is_enrolled_full_time' => false,
            'course_of_study' => 'An amazing program',
            'classes_per_week' => 4,
            'hours_per_week' => 37
          },
          'school_information' => {
            'name' => 'My Great School',
            'training_program' => 'Something amazing',
            'address' => {
              'country_name' => 'USA',
              'address_line1' => '2037 29th St',
              'city' => 'Rock Island',
              'state_code' => 'AR',
              'zip_code' => '61201'
            }
          },
          'student_address_marriage_tuition' => {
            'address' => {
              'country_name' => 'USA',
              'address_line1' => '1019 Robin Cir',
              'city' => 'Arroyo Grande',
              'state_code' => 'CA',
              'zip_code' => '93420'
            },
            'was_married' => true,
            'marriage_date' => '2015-03-04',
            'tuition_is_paid_by_gov_agency' => true,
            'agency_name' => 'Some Agency',
            'date_payments_began' => '2019-02-03'
          },
          'student_name_and_ssn' => {
            'full_name' => {
              'first' => 'Ernie',
              'middle' => 'bubkis',
              'last' => 'McCracken',
              'suffix' => 'II'
            },
            'ssn' => '370947141',
            'birth_date' => '2001-03-03'
          },
          'report674' => true,
          'privacy_agreement_accepted' => true
        },
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
        'current_term_dates' => {
          'official_school_start_date' => '2019-03-03',
          'expected_student_start_date' => '2019-03-05',
          'expected_graduation_date' => '2023-03-03'
        },
        'program_information' => {
          'student_is_enrolled_full_time' => false,
          'course_of_study' => 'An amazing program',
          'classes_per_week' => 4,
          'hours_per_week' => 37
        },
        'student_name_and_ssn' => {
          'full_name' => {
            'first' => 'Ernie',
            'middle' => 'bubkis',
            'last' => 'McCracken',
            'suffix' => 'II'
          },
          'ssn' => '370947141',
          'birth_date' => '2001-03-03'
        },
        'child_stopped_attending_school' => {
          'full_name' => {
            'first' => 'Billy',
            'middle' => 'Yohan',
            'last' => 'Johnson',
            'suffix' => 'Sr.'
          },
          'date_child_left_school' => '2019-03-03'
        }
      }
    end
  end

  factory :form_674_only_v2, class: Hash do
    initialize_with do
      {
        'view:selectable686_options' => {
          'report674' => true
        },
        'dependents_application' => {
          'household_income' => true,
          'veteran_contact_information' => {
            'phone_number' => '5555555555',
            'international_phone_number' => '5555555556',
            'email_address' => 'test@test.com',
            'electronic_correspondence' => true,
            'veteran_address' => {
              'country' => 'USA',
              'street' => '123 fake street',
              'street2' => 'test2',
              'street3' => 'test3',
              'city' => 'portland',
              'state' => 'ME',
              'postal_code' => '04102'
            }
          },
          'student_information' => [{
            'remarks' => 'test additional information',
            'student_networth_information' => {
              'savings' => '500',
              'securities' => '400',
              'real_estate' => '300',
              'other_assets' => '200',
              'total_value' => '1400'
            },
            'student_expected_earnings_next_year' => {
              'earnings_from_all_employment' => '56000',
              'annual_social_security_payments' => '0',
              'other_annuities_income' => '145',
              'all_other_income' => '50'
            },
            'student_earnings_from_school_year' => {
              'earnings_from_all_employment' => '56000',
              'annual_social_security_payments' => '0',
              'other_annuities_income' => '123',
              'all_other_income' => '20'
            },
            'claims_or_receives_pension' => true,
            'school_information' => {
              'last_term_school_information' => {
                'term_begin' => '2024-01-01',
                'date_term_ended' => '2024-03-05'
              },
              'student_did_attend_school_last_term' => true,
              'current_term_dates' => {
                'official_school_start_date' => '2025-01-01',
                'expected_student_start_date' => '2025-01-02',
                'expected_graduation_date' => '2026-03-01'
              },
              'is_school_accredited' => true,
              'student_is_enrolled_full_time' => true,
              'name' => 'name of trade program'
            },
            'benefit_payment_date' => '2024-03-01',
            'type_of_program_or_benefit' => { 'ch35' => true, 'fry' => true, 'feca' => true, 'other' => true },
            'other_program_or_benefit' => 'all the programs!',
            'tuition_is_paid_by_gov_agency' => true,
            'marriage_date' => '2024-03-03',
            'was_married' => true,
            'address' => {
              'country' => 'USA',
              'street' => '123 fake street',
              'street2' => 'line2',
              'street3' => 'line3',
              'city' => 'portland',
              'state' => 'ME',
              'postal_code' => '04102'
            },
            'student_income' => true,
            'ssn' => '987654321',
            'is_parent' => true,
            'full_name' => { 'first' => 'test', 'middle' => 'middle', 'last' => 'student' },
            'birth_date' => '2005-01-01'
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

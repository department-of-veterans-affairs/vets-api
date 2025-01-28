# frozen_string_literal: true

FactoryBot.define do
  factory :form_686c_674_kitchen_sink, class: Hash do
    initialize_with do
      {
        'veteran_was_married_before' => true,
        'spouse_was_married_before' => true,
        'view:selectable686_options' => {
          'add_spouse' => true,
          'add_child' => true,
          'report674' => true,
          'report_divorce' => true,
          'report_stepchild_not_in_household' => true,
          'report_death' => true,
          'report_marriage_of_child_under18' => true,
          'report_child18_or_older_is_not_attending_school' => true
        },
        'veteran_information' => {
          'birth_date' => '1809-02-12',
          'full_name' => {
            'first' => 'WESLEY',
            'last' => 'FORD',
            'middle' => nil
          }, 'ssn' => '796043735',
          'va_file_number' => '796043735'
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
          'report_divorce' => {
            'full_name' => {
              'first' => 'Jenifer',
              'middle' => 'a',
              'last' => 'Myers'
            },
            'date' => '2020-01-01',
            'location' => {
              'state' => 'FL',
              'city' => 'Tampa'
            },
            'reason_marriage_ended' => 'Divorce',
            'ssn' => '579854687',
            'birth_date' => '1994-03-03'
          },
          'view:selectable686_options' => {
            'report_divorce' => true
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
              'address_line1' => '20374 twenty ninth St',
              'address_line2' => 'apt 1',
              'address_line3' => 'flat 3',
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
            'expected_graduation_date' => '2023-03-03',
            'is_school_accredited' => true
          },
          'program_information' => {
            'student_is_enrolled_full_time' => true,
            'course_of_study' => 'An amazing program',
            'classes_per_week' => 4,
            'hours_per_week' => 37
          },
          'school_information' => {
            'name' => 'My Great School',
            'school_type' => 'HighSch',
            'training_program' => 'Something amazing',
            'address' => {
              'country_name' => 'USA',
              'address_line1' => '55 twenty ninth St',
              'address_line2' => 'Bldg 5',
              'address_line3' => 'No. 5',
              'city' => 'Rock Island',
              'state_code' => 'AR',
              'zip_code' => '61201'
            }
          },
          'student_address_marriage_tuition' => {
            'address' => {
              'country_name' => 'USA',
              'address_line1' => '20374 Alexander Hamilton St',
              'address_line2' => 'apt 4',
              'address_line3' => 'Bldg 44',
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
            'birth_date' => '2001-03-03',
            'dependent_income' => true
          },
          'step_children' => [
            {
              'supporting_stepchild' => true,
              'living_expenses_paid' => 'Half',
              'who_does_the_stepchild_live_with' => {
                'first' => 'Adam',
                'middle' => 'Steven',
                'last' => 'Huberws'
              },
              'address' => {
                'country_name' => 'USA',
                'address_line1' => '2666999 Veteran Street',
                'address_line2' => 'Bldg 51',
                'address_line3' => 'flat 10000',
                'city' => 'Clawson',
                'state_code' => 'AL',
                'zip_code' => '48017'
              },
              'full_name' => {
                'first' => 'Billy',
                'middle' => 'Bob',
                'last' => 'Thorton'
              },
              'ssn' => '231547897',
              'birth_date' => '2010-01-01'
            }
          ],
          'child_stopped_attending_school' => {
            'full_name' => {
              'first' => 'Billy',
              'middle' => 'Yohan',
              'last' => 'Johnson',
              'suffix' => 'Sr.'
            },
            'ssn' => '897524564',
            'birth_date' => '2005-01-02',
            'date_child_left_school' => '2019-03-03'
          },
          'child_marriage' => {
            'full_name' => {
              'first' => 'James',
              'middle' => 'Quandry',
              'last' => 'Beanstalk',
              'suffix' => 'Sr.'
            },
            'ssn' => '879534579',
            'birth_date' => '2012-01-04',
            'date_married' => '1977-02-01'
          },
          'deaths' => [
            {
              'date' => '2011-02-03',
              'location' => {
                'state' => 'CA',
                'city' => 'Aomplea'
              },
              'full_name' => {
                'first' => 'John',
                'middle' => 'Henry',
                'last' => 'Doe',
                'suffix' => 'Sr.'
              },
              'dependent_type' => 'CHILD',
              'ssn' => '987459874',
              'birth_date' => '1990-01-01',
              'child_status' => {
                'child_under18' => true
              }
            },
            {
              'date' => '2020-01-01',
              'location' => {
                'state' => 'CA',
                'city' => 'Aomplea'
              },
              'full_name' => {
                'first' => 'Frida',
                'last' => 'Mission'
              },
              'dependent_type' => 'SPOUSE',
              'ssn' => '987459874',
              'birth_date' => '1995-01-01'
            }
          ],
          'veteran_was_married_before' => true,
          'veteran_marriage_history' => [
            {
              'start_date' => '2007-04-03',
              'start_location' => {
                'state' => 'AK',
                'city' => 'Rock Island'
              },
              'reason_marriage_ended' => 'Other',
              'reason_marriage_ended_other' => 'Some other reason',
              'end_date' => '2009-05-05',
              'end_location' => {
                'state' => 'IL',
                'city' => 'Rock Island'
              },
              'full_name' => {
                'first' => 'Sansa',
                'middle' => 'Bigfoot',
                'last' => 'Stark',
                'suffix' => 'III'
              }
            }
          ],
          'spouse_was_married_before' => true,
          'spouse_marriage_history' => [
            {
              'start_date' => '2008-03-03',
              'start_location' => {
                'state' => 'IL',
                'city' => 'Rock Island'
              },
              'reason_marriage_ended' => 'Death',
              'end_date' => '2010-03-04',
              'end_location' => {
                'state' => 'IL',
                'city' => 'Rock Island'
              },
              'full_name' => {
                'first' => 'Clovis',
                'middle' => 'Nigel',
                'last' => 'The Cat',
                'suffix' => 'Sr.'
              }
            }
          ],
          'does_live_with_spouse' => {
            'spouse_does_live_with_veteran' => false,
            'current_spouse_reason_for_separation' => 'Other',
            'address' => {
              'country_name' => 'USA',
              'address_line1' => '20374 Forty Seventh Avenue',
              'address_line2' => 'apt 9000',
              'address_line3' => 'flat 3',
              'city' => 'Rock Island',
              'state_code' => 'IL',
              'zip_code' => '61201'
            }
          },
          'current_marriage_information' => {
            'date' => '2014-03-04',
            'location' => {
              'state' => 'CA',
              'city' => 'Slawson'
            },
            'type' => 'OTHER',
            'type_other' => 'Some Other Thing'
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
          'children_to_add' => [
            {
              'does_child_live_with_you' => false,
              'child_address_info' => {
                'person_child_lives_with' => {
                  'first' => 'Bill',
                  'middle' => 'Oliver',
                  'last' => 'Bradsky'
                },
                'address' => {
                  'country_name' => 'USA',
                  'address_line1' => 'One thousand five Lincoln Street',
                  'address_line2' => 'apt 609',
                  'address_line3' => 'flat 333',
                  'city' => 'Los Angelas',
                  'state_code' => 'CA',
                  'zip_code' => '90210'
                }
              },
              'place_of_birth' => {
                'state' => 'CA',
                'city' => 'Slawson'
              },
              'child_status' => {
                'biological' => true
              },
              'previously_married' => 'Yes',
              'previous_marriage_details' => {
                'date_marriage_ended' => '2018-03-04',
                'reason_marriage_ended' => 'Death'
              },
              'full_name' => {
                'first' => 'John',
                'middle' => 'oliver',
                'last' => 'Hamm',
                'suffix' => 'Sr.'
              },
              'ssn' => '370947142',
              'birth_date' => '2009-03-03'
            },
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
          ],
          'veteran_contact_information' => {
            'veteran_address' => {
              'country_name' => 'USA',
              'address_line1' => '2037400 twenty ninth St',
              'address_line2' => 'apt 2222',
              'address_line3' => 'Bldg 33333',
              'city' => 'Pasadena',
              'state_code' => 'CA',
              'zip_code' => '21122'
            },
            'phone_number' => '1112223333',
            'email_address' => 'foo@foo.com'
          },
          'household_income' => true,
          'add_child' => true,
          'add_spouse' => true,
          'report_death' => true,
          'report_stepchild_not_in_household' => true,
          'report_marriage_of_child_under18' => true,
          'report_child18_or_older_is_not_attending_school' => true,
          'report674' => true,
          'privacy_agreement_accepted' => true
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
        'veteran_contact_information' => {
          'veteran_address' => {
            'country_name' => 'USA',
            'address_line1' => '2037400 twenty ninth St',
            'address_line2' => 'apt 2222',
            'address_line3' => 'Bldg 33333',
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
        },
        'does_live_with_spouse' => {
          'spouse_does_live_with_veteran' => false,
          'current_spouse_reason_for_separation' => 'Other',
          'address' => {
            'country_name' => 'USA',
            'address_line1' => '20374 Forty Seventh Avenue',
            'address_line2' => 'apt 9000',
            'address_line3' => 'flat 3',
            'city' => 'Rock Island',
            'state_code' => 'IL',
            'zip_code' => '61201'
          }
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
    end
  end

  factory :form_686c_add_child_report674, class: Hash do
    initialize_with do
      {
        'view:selectable686_options' => {
          'add_child' => true,
          'report674' => true
        },
        'veteran_information' => {
          'birth_date' => '1809-02-12',
          'full_name' => {
            'first' => 'WESLEY',
            'last' => 'FORD',
            'middle' => nil
          }, 'ssn' => '796043735',
          'va_file_number' => '796043735'
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
          'report_divorce' => {
            'full_name' => {
              'first' => 'Jenifer',
              'middle' => 'a',
              'last' => 'Myers'
            },
            'date' => '2020-01-01',
            'location' => {
              'state' => 'FL',
              'city' => 'Tampa'
            },
            'reason_marriage_ended' => 'Divorce',
            'ssn' => '579854687',
            'birth_date' => '1994-03-03'
          },
          'view:selectable686_options' => {
            'report_divorce' => true
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
              'address_line1' => '20374 twenty ninth St',
              'address_line2' => 'apt 1',
              'address_line3' => 'flat 3',
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
            'school_type' => 'HighSch',
            'training_program' => 'Something amazing',
            'address' => {
              'country_name' => 'USA',
              'address_line1' => '55 twenty ninth St',
              'address_line2' => 'Bldg 5',
              'address_line3' => 'No. 5',
              'city' => 'Rock Island',
              'state_code' => 'AR',
              'zip_code' => '61201'
            }
          },
          'student_address_marriage_tuition' => {
            'address' => {
              'country_name' => 'USA',
              'address_line1' => '20374 Alexander Hamilton St',
              'address_line2' => 'apt 4',
              'address_line3' => 'Bldg 44',
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
            'birth_date' => '2001-03-03',
            'dependent_income' => true
          },
          'step_children' => [
            {
              'supporting_stepchild' => true,
              'living_expenses_paid' => 'Half',
              'who_does_the_stepchild_live_with' => {
                'first' => 'Adam',
                'middle' => 'Steven',
                'last' => 'Huberws'
              },
              'address' => {
                'country_name' => 'USA',
                'address_line1' => '2666999 Veteran Street',
                'address_line2' => 'Bldg 51',
                'address_line3' => 'flat 10000',
                'city' => 'Clawson',
                'state_code' => 'AL',
                'zip_code' => '48017'
              },
              'full_name' => {
                'first' => 'Billy',
                'middle' => 'Bob',
                'last' => 'Thorton'
              },
              'ssn' => '231547897',
              'birth_date' => '2010-01-01'
            }
          ],
          'child_stopped_attending_school' => {
            'full_name' => {
              'first' => 'Billy',
              'middle' => 'Yohan',
              'last' => 'Johnson',
              'suffix' => 'Sr.'
            },
            'ssn' => '897524564',
            'birth_date' => '2005-01-02',
            'date_child_left_school' => '2019-03-03'
          },
          'child_marriage' => {
            'full_name' => {
              'first' => 'James',
              'middle' => 'Quandry',
              'last' => 'Beanstalk',
              'suffix' => 'Sr.'
            },
            'ssn' => '879534579',
            'birth_date' => '2012-01-04',
            'date_married' => '1977-02-01'
          },
          'deaths' => [
            {
              'date' => '2011-02-03',
              'location' => {
                'state' => 'CA',
                'city' => 'Aomplea'
              },
              'full_name' => {
                'first' => 'John',
                'middle' => 'Henry',
                'last' => 'Doe',
                'suffix' => 'Sr.'
              },
              'dependent_type' => 'CHILD',
              'ssn' => '987459874',
              'birth_date' => '1990-01-01',
              'child_status' => {
                'child_under18' => true
              }
            },
            {
              'date' => '2020-01-01',
              'location' => {
                'state' => 'CA',
                'city' => 'Aomplea'
              },
              'full_name' => {
                'first' => 'Frida',
                'last' => 'Mission'
              },
              'dependent_type' => 'SPOUSE',
              'ssn' => '987459874',
              'birth_date' => '1995-01-01'
            }
          ],
          'veteran_was_married_before' => true,
          'veteran_marriage_history' => [
            {
              'start_date' => '2007-04-03',
              'start_location' => {
                'state' => 'AK',
                'city' => 'Rock Island'
              },
              'reason_marriage_ended' => 'Other',
              'reason_marriage_ended_other' => 'Some other reason',
              'end_date' => '2009-05-05',
              'end_location' => {
                'state' => 'IL',
                'city' => 'Rock Island'
              },
              'full_name' => {
                'first' => 'Sansa',
                'middle' => 'Bigfoot',
                'last' => 'Stark',
                'suffix' => 'III'
              }
            }
          ],
          'spouse_was_married_before' => true,
          'spouse_marriage_history' => [
            {
              'start_date' => '2008-03-03',
              'start_location' => {
                'state' => 'IL',
                'city' => 'Rock Island'
              },
              'reason_marriage_ended' => 'Death',
              'end_date' => '2010-03-04',
              'end_location' => {
                'state' => 'IL',
                'city' => 'Rock Island'
              },
              'full_name' => {
                'first' => 'Clovis',
                'middle' => 'Nigel',
                'last' => 'The Cat',
                'suffix' => 'Sr.'
              }
            }
          ],
          'does_live_with_spouse' => {
            'spouse_does_live_with_veteran' => false,
            'current_spouse_reason_for_separation' => 'Other',
            'address' => {
              'country_name' => 'USA',
              'address_line1' => '20374 Forty Seventh Avenue',
              'address_line2' => 'apt 9000',
              'address_line3' => 'flat 3',
              'city' => 'Rock Island',
              'state_code' => 'IL',
              'zip_code' => '61201'
            }
          },
          'current_marriage_information' => {
            'date' => '2014-03-04',
            'location' => {
              'state' => 'CA',
              'city' => 'Slawson'
            },
            'type' => 'OTHER',
            'type_other' => 'Some Other Thing'
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
          'children_to_add' => [
            {
              'does_child_live_with_you' => false,
              'child_address_info' => {
                'person_child_lives_with' => {
                  'first' => 'Bill',
                  'middle' => 'Oliver',
                  'last' => 'Bradsky'
                },
                'address' => {
                  'country_name' => 'USA',
                  'address_line1' => 'One thousand five Lincoln Street',
                  'address_line2' => 'apt 609',
                  'address_line3' => 'flat 333',
                  'city' => 'Los Angelas',
                  'state_code' => 'CA',
                  'zip_code' => '90210'
                }
              },
              'place_of_birth' => {
                'state' => 'CA',
                'city' => 'Slawson'
              },
              'child_status' => {
                'biological' => true
              },
              'previously_married' => 'Yes',
              'previous_marriage_details' => {
                'date_marriage_ended' => '2018-03-04',
                'reason_marriage_ended' => 'Death'
              },
              'full_name' => {
                'first' => 'John',
                'middle' => 'oliver',
                'last' => 'Hamm',
                'suffix' => 'Sr.'
              },
              'ssn' => '370947142',
              'birth_date' => '2009-03-03'
            },
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
          ],
          'veteran_contact_information' => {
            'veteran_address' => {
              'country_name' => 'USA',
              'address_line1' => '2037400 twenty ninth St',
              'address_line2' => 'apt 2222',
              'address_line3' => 'Bldg 33333',
              'city' => 'Pasadena',
              'state_code' => 'CA',
              'zip_code' => '21122'
            },
            'phone_number' => '1112223333',
            'email_address' => 'foo@foo.com'
          },
          'household_income' => true,
          'add_child' => true,
          'add_spouse' => true,
          'report_death' => true,
          'report_stepchild_not_in_household' => true,
          'report_marriage_of_child_under18' => true,
          'report_child18_or_older_is_not_attending_school' => true,
          'report674' => true,
          'privacy_agreement_accepted' => true
        },
        'veteran_contact_information' => {
          'veteran_address' => {
            'country_name' => 'USA',
            'address_line1' => '2037400 twenty ninth St',
            'address_line2' => 'apt 2222',
            'address_line3' => 'Bldg 33333',
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
end

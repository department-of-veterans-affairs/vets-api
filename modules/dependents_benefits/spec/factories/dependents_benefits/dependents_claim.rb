# frozen_string_literal: true

FactoryBot.define do
  factory :dependents_claim, class: 'DependentsBenefits::PrimaryDependencyClaim' do
    form_id { '686C-674-V2' }

    form do
      {
        statement_of_truth_certified: true,
        statement_of_truth_signature: 'Mark Webb',
        'view:selectable686_options': {
          add_spouse: true,
          add_child: true,
          report674: true,
          add_disabled_child: true,
          report_divorce: true,
          report_death: true,
          report_stepchild_not_in_household: true,
          report_marriage_of_child_under18: true,
          report_child18_or_older_is_not_attending_school: true
        },
        dependents_application: {
          household_income: true,
          'view:completed_child_stopped_attending_school': false,
          'view:completed_married_child': false,
          'view:completed_dependent': false,
          'view:completed_household_child': false,
          report_divorce: {
            spouse_income: true,
            date: '2023-11-03',
            divorce_location: {
              location: {
                city: 'louisville',
                state: 'KY',
                country: 'US'
              }
            },
            reason_marriage_ended: 'Divorce',
            full_name: {
              first: 'removing',
              middle: 'former',
              last: 'spouse'
            },
            birth_date: '1980-02-03'
          },
          'view:completed_student': false,
          'view:completed_add_child': false,
          'view:completed_veteran_former_marriage': false,
          'view:completed_spouse_former_marriage': false,
          current_marriage_information: {
            type_of_marriage: 'CIVIL',
            location: {
              city: 'washington',
              state: 'DC'
            },
            date: '2024-02-01'
          },
          does_live_with_spouse: {
            spouse_income: true,
            current_spouse_reason_for_separation: 'Other',
            other: 'other reasons',
            address: {
              country: 'US',
              street: '456 fake street',
              street2: 'This is a very long apartment name and number',
              city: 'portland',
              state: 'ME',
              postal_code: '04102'
            },
            spouse_does_live_with_veteran: false
          },
          spouse_information: {
            va_file_number: '987654321',
            service_number: '987654321',
            ssn: '987654321',
            birth_date: '1977-01-01',
            is_veteran: true,
            full_name: {
              first: 'test',
              middle: 'middle',
              last: 'spouselast'
            }
          },
          veteran_contact_information: {
            phone_number: '5555555555',
            international_phone_number: '1234567890',
            email_address: 'test@test.com',
            electronic_correspondence: true,
            veteran_address: {
              country: 'USA',
              street: '123 fake street',
              street2: 'this is a really long apartment number',
              street3: 'test3',
              city: 'portland',
              state: 'ME',
              postal_code: '04102'
            }
          },
          'view:remove_dependent_options': {
            report_divorce: true,
            report_death: true,
            report_stepchild_not_in_household: true,
            report_marriage_of_child_under18: true,
            report_child18_or_older_is_not_attending_school: true
          },
          'view:add_dependent_options': {
            add_spouse: true,
            add_child: true,
            report674: true,
            add_disabled_child: true
          },
          'view:add_or_remove_dependents': { add: true, remove: true },
          spouse_marriage_history: [
            {
              end_location: { location: { city: 'denver', state: 'CO' } },
              start_location: { outside_usa: true, location: { city: 'denver', state: 'CO' } },
              end_date: '2010-07-06',
              start_date: '2010-03-05',
              reason_marriage_ended: 'Other',
              other_reason_marriage_ended: 'annulled',
              full_name: { first: 'test', middle: 'middle', last: 'spouseformerone' }
            },
            {
              end_location: { location: { city: 'boston', state: 'MA' } },
              start_location: {
                outside_usa: true,
                location: {
                  city: 'fayetteville',
                  state: 'AR'
                }
              },
              end_date: '2013-08-08',
              start_date: '2011-07-12',
              reason_marriage_ended: 'Divorce',
              full_name: { first: 'test', middle: 'middle', last: 'spouseformertwo' }
            },
            {
              end_location: { location: { city: 'portland', state: 'ME' } },
              start_location: { outside_usa: true, location: { city: 'washington', state: 'DC' } },
              end_date: '2015-07-06',
              start_date: '2014-09-06',
              reason_marriage_ended: 'Death',
              full_name: { first: 'test', middle: 'middle', last: 'spouseformerthree' }
            },
            {
              end_location: { location: { city: 'burlington', state: 'VT' } },
              start_location: { outside_usa: true, location: { city: 'wilmington', state: 'DE' } },
              end_date: '2019-11-09',
              start_date: '2016-10-11',
              reason_marriage_ended: 'Divorce',
              full_name: { first: 'test', middle: 'middle', last: 'spouseformerfour' }
            }
          ],
          veteran_marriage_history: [
            {
              end_location: { location: { city: 'miami', state: 'FL' } },
              start_location: { location: { city: 'san diego', state: 'CA' } },
              end_date: '2010-07-06',
              start_date: '2010-03-02',
              reason_marriage_ended: 'Divorce',
              full_name: { first: 'test', middle: 'middle', last: 'formerspouseone' }
            },
            {
              end_location: { location: { city: 'boise', state: 'ID' } },
              start_location: { location: { city: 'atlanta', state: 'GA' } },
              end_date: '2011-12-06',
              start_date: '2011-08-02',
              reason_marriage_ended: 'Other',
              other_reason_marriage_ended: 'annulled',
              full_name: { first: 'test', middle: 'middle', last: 'formerspousetwo' }
            },
            {
              end_location: { location: { city: 'baltimore', state: 'MD' } },
              start_location: { location: { city: 'lawrence', state: 'KS' } },
              end_date: '2014-11-10',
              start_date: '2013-10-10',
              reason_marriage_ended: 'Death',
              full_name: { first: 'test', middle: 'middle', last: 'formerspousethree' }
            },
            {
              end_location: { location: { city: 'charlotte', state: 'NC' } },
              start_location: { location: { city: 'concord', state: 'NH' } },
              end_date: '2019-07-07',
              start_date: '2016-10-06',
              reason_marriage_ended: 'Divorce',
              full_name: { first: 'test', middle: 'middle', last: 'formerspousefour' }
            }
          ],
          children_to_add: [
            {
              income_in_last_year: true,
              marriage_end_date: '2023-07-03',
              marriage_end_reason: 'Divorce',
              marriage_end_description: 'short',
              does_child_live_with_you: false,
              has_child_ever_been_married: true,
              is_biological_child_of_spouse: false,
              relationship_to_child: { adopted: false, stepchild: false },
              does_child_have_permanent_disability: false,
              is_biological_child: true,
              birth_location: {
                location: {
                  city: 'quebec',
                  postal_code: '03301',
                  country: 'CAN'
                }
              },
              ssn: '987654321',
              full_name: { first: 'test', middle: 'middle', last: 'childone' },
              birth_date: '2005-01-02',
              address: {
                country: 'USA',
                street: '123 fake drive',
                street2: 'This is a really long apartment number',
                street3: 'line3',
                city: 'concord',
                state: 'NH',
                postal_code: '03301'
              },
              living_with: { first: 'test', last: 'person' },
              does_child_have_disability: true,
              biological_parent_name: { first: 'bio', middle: 'log', last: 'cal' },
              biological_parent_ssn: '000000000',
              school_age_in_school: false
            },
            {
              income_in_last_year: false,
              marriage_end_reason: 'annulment',
              marriage_end_description: 'description of annulment really long text here over length 16',
              does_child_live_with_you: true,
              has_child_ever_been_married: false,
              is_biological_child_of_spouse: true,
              relationship_to_child: { stepchild: true },
              is_biological_child: false,
              biological_parent_name: { first: 'bio', middle: 'log', last: 'cal' },
              biological_parent_ssn: '000000000',
              does_child_have_permanent_disability: true,
              birth_location: {
                location: {
                  state: 'DC',
                  city: 'washington',
                  postal_code: '03301'
                }
              },
              ssn: '987654321',
              full_name: { first: 'test', middle: 'middle', last: 'childtwo' },
              birth_date: '2009-04-05',
              date_entered_household: '2024-05-04',
              school_age_in_school: false
            },
            {
              marriage_end_reason: 'annulment',
              marriage_end_description: 'description of annulment',
              does_child_live_with_you: true,
              has_child_ever_been_married: false,
              relationship_to_child: { adopted: true },
              birth_location: {
                location: {
                  state: 'AR',
                  city: 'bentonville',
                  postal_code: '03301'
                }
              },
              ssn: '987654321',
              full_name: { first: 'test', middle: 'middle', last: 'childthree' },
              birth_date: '2010-04-06',
              school_age_in_school: false
            },
            {
              income_in_last_year: false,
              marriage_end_reason: 'annulment',
              marriage_end_description: 'description of annulment',
              does_child_live_with_you: true,
              has_child_ever_been_married: false,
              relationship_to_child: { adopted: false },
              is_biological_child: true,
              birth_location: {
                location: {
                  state: 'SC',
                  city: 'charleston',
                  postal_code: '03301'
                }
              },
              ssn: '987654321',
              full_name: { first: 'test', middle: 'middle', last: 'childfour' },
              birth_date: '2015-09-07',
              school_age_in_school: false
            },
            {
              income_in_last_year: true,
              marriage_end_reason: 'annulment',
              marriage_end_description: 'description of annulment',
              does_child_live_with_you: true,
              has_child_ever_been_married: false,
              relationship_to_child: { adopted: true },
              is_biological_child: false,
              birth_location: { location: { state: 'NH', city: 'durham', postal_code: '03301' } },
              biological_parent_name: { first: 'bio', middle: 'log', last: 'cal' },
              biological_parent_ssn: '000000000',
              ssn: '987654321',
              full_name: { first: 'test', middle: 'middle', last: 'childfive' },
              birth_date: '2019-10-08',
              school_age_in_school: false
            },
            {
              income_in_last_year: false,
              marriage_end_reason: 'annulment',
              marriage_end_description: 'description of annulment',
              does_child_live_with_you: true,
              has_child_ever_been_married: false,
              relationship_to_child: { adopted: false },
              is_biological_child: true,
              birth_location: { location: { state: 'NY', city: 'new york', postal_code: '03301' } },
              ssn: '987654321',
              full_name: { first: 'test', middle: 'middle', last: 'childsix' },
              birth_date: '2023-11-07',
              school_age_in_school: false
            }
          ],
          student_information: [{
            remarks: 'test additional information',
            student_networth_information: {
              savings: '500',
              securities: '400',
              real_estate: '300',
              other_assets: '200',
              total_value: '1400'
            },
            student_expected_earnings_next_year: {
              earnings_from_all_employment: '56000',
              annual_social_security_payments: '0',
              other_annuities_income: '145',
              all_other_income: '50'
            },
            student_earnings_from_school_year: {
              earnings_from_all_employment: '56000',
              annual_social_security_payments: '0',
              other_annuities_income: '123',
              all_other_income: '20'
            },
            claims_or_receives_pension: true,
            school_information: {
              last_term_school_information: { term_begin: '2024-01-01', date_term_ended: '2024-03-05' },
              date_full_time_ended: '2024-05-05',
              student_did_attend_school_last_term: true,
              current_term_dates: {
                official_school_start_date: '2025-01-01',
                expected_student_start_date: '2025-01-02',
                expected_graduation_date: '2026-03-01'
              },
              is_school_accredited: true,
              student_is_enrolled_full_time: true,
              name: 'name of trade program'
            },
            benefit_payment_date: '2024-03-01',
            type_of_program_or_benefit: { ch35: true, fry: true, feca: true, other: true },
            other_program_or_benefit: 'all the programs!',
            tuition_is_paid_by_gov_agency: true,
            marriage_date: '2024-03-03',
            was_married: true,
            address: {
              country: 'USA',
              street: '123 fake street',
              street2: 'line2',
              street3: 'line3',
              city: 'portland',
              state: 'ME',
              postal_code: '04102'
            },
            student_income: true,
            ssn: '987654321',
            relationship_to_student: 'biological',
            full_name: {
              first: 'test',
              middle: 'middle',
              last: 'student'
            },
            birth_date: '2005-01-01'
          }],
          step_children: [
            {
              who_does_the_stepchild_live_with: {
                first: 'parent',
                middle: 'middle',
                last: 'name'
              },
              living_expenses_paid: 'More than half',
              address: {
                country: 'USA',
                street: '456 fake street',
                street2: 'this is a very long apartment number',
                street3: 'line3',
                city: 'portland',
                state: 'ME',
                postal_code: '04102'
              },
              supporting_stepchild: false,
              full_name: { first: 'stepchild', middle: 'middle', last: 'leaving' },
              ssn: '987654321',
              birth_date: '2009-04-01'
            },
            {
              who_does_the_stepchild_live_with: {
                first: 'parent',
                middle: 'middle',
                last: 'parentname'
              },
              address: {
                country: 'USA',
                street: '123 ocean avenue',
                street2: 'this is a very long apartment number',
                street3: 'line3',
                city: 'concord',
                state: 'NH',
                postal_code: '03301'
              },
              supporting_stepchild: false,
              full_name: { first: 'second', middle: 'middle', last: 'stepchild' },
              ssn: '987654321',
              birth_date: '2009-04-01'
            }
          ],
          deaths: [
            {
              deceased_dependent_income: true,
              dependent_death_location: { location: { city: 'new orleans', state: 'LA', country: 'USA' } },
              dependent_death_date: '2024-03-02',
              dependent_type: 'DEPENDENT_PARENT',
              full_name: { first: 'deceased', middle: 'middle', last: 'dependent' },
              ssn: '987654321',
              birth_date: '1960-01-01'
            },
            {
              deceased_dependent_income: true,
              dependent_death_location: { location: { city: 'new orleans', state: 'LA', country: 'USA' } },
              dependent_death_date: '2024-03-02',
              dependent_type: 'CHILD',
              child_status: { child_under18: true, step_child: true },
              full_name: { first: 'deceased', middle: 'middle', last: 'dependent' },
              ssn: '987654321',
              birth_date: '1990-01-01'
            },
            {
              deceased_dependent_income: false,
              dependent_death_location: { location: { city: 'denver', state: 'CO' } },
              dependent_death_date: '2023-10-03',
              dependent_type: 'SPOUSE',
              full_name: { first: 'other', middle: 'middle', last: 'deceased' },
              ssn: '987654321',
              birth_date: '1960-01-01'
            }
          ],
          child_marriage: [{
            dependent_income: false,
            date_married: '2023-06-03',
            full_name: { first: 'child', middle: 'middle', last: 'married' },
            ssn: '987654321',
            birth_date: '2008-04-05'
          }],
          child_stopped_attending_school: [{
            dependent_income: false,
            date_child_left_school: '2023-04-03',
            full_name: { first: 'removing', middle: 'middle', last: 'child' },
            ssn: '987654321',
            birth_date: '2005-05-01'
          }],
          'view:selectable686_options': {
            add_spouse: true,
            add_child: true,
            report674: true,
            add_disabled_child: true,
            report_divorce: true,
            report_death: true,
            report_stepchild_not_in_household: true,
            report_marriage_of_child_under18: true,
            report_child18_or_older_is_not_attending_school: true
          },
          days_till_expires: 365,
          privacy_agreement_accepted: true
        },
        veteran_information: {
          birth_date: '1980-01-01',
          full_name: {
            first: 'Mark',
            last: 'Webb'
          },
          ssn: '000000000',
          va_file_number: '000000000'
        }
      }.to_json
    end
  end

  factory :student_claim, class: 'DependentsBenefits::SchoolAttendanceApproval' do
    form_id { '21-674' }

    form do
      {
        'view:selectable686_options' => {
          'report674' => true
        },
        'veteran_information' => {
          'birth_date' => '1980-01-01',
          'full_name' => { 'first' => 'Mark', 'last' => 'Webb' },
          'ssn' => '000000000',
          'va_file_number' => '000000000'
        },
        'statement_of_truth_signature' => 'Mark Webb',
        'statement_of_truth_certified' => true,
        'dependents_application' => {
          'veteran_contact_information' => {
            'phone_number' => '5555555555',
            'international_phone_number' => '1234567890',
            'email_address' => 'test@test.com',
            'electronic_correspondence' => true,
            'veteran_address' => {
              'country' => 'USA',
              'street' => '123 fake street',
              'street2' => 'this is a really long apartment number',
              'street3' => 'test3',
              'city' => 'portland',
              'state' => 'ME',
              'postal_code' => '04102'
            }
          },
          'view:completed_child_stopped_attending_school' => false,
          'view:add_or_remove_dependents' => { 'add' => true, 'remove' => true },
          'view:remove_dependent_options' => {
            'report_divorce' => true,
            'report_death' => true,
            'report_stepchild_not_in_household' => true,
            'report_marriage_of_child_under18' => true,
            'report_child18_or_older_is_not_attending_school' => true
          },
          'view:selectable686_options' => {
            'report674' => true
          },
          'child_stopped_attending_school' => [{
            'dependent_income' => false,
            'date_child_left_school' => '2023-04-03',
            'full_name' => { 'first' => 'removing', 'middle' => 'middle', 'last' => 'child' },
            'ssn' => '987654321',
            'birth_date' => '2005-05-01'
          }],
          'days_till_expires' => 365,
          'privacy_agreement_accepted' => true,
          'student_information' => [
            {
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
                'date_full_time_ended' => '2024-05-05',
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
              'relationship_to_student' => 'biological',
              'full_name' => {
                'first' => 'test',
                'middle' => 'middle',
                'last' => 'student'
              },
              'birth_date' => '2005-01-01'
            }
          ]
        }
      }.to_json
    end
  end

  factory :add_remove_dependents_claim, class: 'DependentsBenefits::AddRemoveDependent' do
    form_id { '21-686C' }

    form do
      {
        'veteran_information' => {
          'birth_date' => '1980-01-01',
          'full_name' => { 'first' => 'Mark', 'last' => 'Webb' },
          'ssn' => '000000000',
          'va_file_number' => '000000000'
        },
        'statement_of_truth_signature' => 'Mark Webb',
        'statement_of_truth_certified' => true,
        'dependents_application' => {
          'veteran_contact_information' => {
            'phone_number' => '5555555555',
            'international_phone_number' => '1234567890',
            'email_address' => 'test@test.com',
            'electronic_correspondence' => true,
            'veteran_address' => {
              'country' => 'USA',
              'street' => '123 fake street',
              'street2' => 'this is a really long apartment number',
              'street3' => 'test3',
              'city' => 'portland',
              'state' => 'ME',
              'postal_code' => '04102'
            }
          },
          'household_income' => true,
          'spouse_information' => {
            'va_file_number' => '987654321',
            'service_number' => '987654321',
            'ssn' => '987654321',
            'birth_date' => '1977-01-01',
            'is_veteran' => true,
            'full_name' => { 'first' => 'test', 'middle' => 'middle', 'last' => 'spouselast' }
          },
          'current_marriage_information' => {
            'type_of_marriage' => 'CIVIL',
            'location' => { 'city' => 'washington', 'state' => 'DC' },
            'date' => '2024-02-01'
          },
          'does_live_with_spouse' => {
            'spouse_income' => true,
            'current_spouse_reason_for_separation' => 'Other',
            'other' => 'other reasons',
            'address' => {
              'country' => 'US',
              'street' => '456 fake street',
              'street2' => 'This is a very long apartment name and number',
              'city' => 'portland',
              'state' => 'ME',
              'postal_code' => '04102'
            },
            'spouse_does_live_with_veteran' => false
          },
          'veteran_marriage_history' => [
            {
              'end_location' => { 'location' => { 'city' => 'miami', 'state' => 'FL' } },
              'start_location' => { 'location' => { 'city' => 'san diego', 'state' => 'CA' } },
              'end_date' => '2010-07-06',
              'start_date' => '2010-03-02',
              'reason_marriage_ended' => 'Divorce',
              'full_name' => { 'first' => 'test', 'middle' => 'middle', 'last' => 'formerspouseone' }
            },
            {
              'end_location' => { 'location' => { 'city' => 'boise', 'state' => 'ID' } },
              'start_location' => { 'location' => { 'city' => 'atlanta', 'state' => 'GA' } },
              'end_date' => '2011-12-06',
              'start_date' => '2011-08-02',
              'reason_marriage_ended' => 'Other',
              'other_reason_marriage_ended' => 'annulled',
              'full_name' => { 'first' => 'test', 'middle' => 'middle', 'last' => 'formerspousetwo' }
            },
            {
              'end_location' => { 'location' => { 'city' => 'baltimore', 'state' => 'MD' } },
              'start_location' => { 'location' => { 'city' => 'lawrence', 'state' => 'KS' } },
              'end_date' => '2014-11-10',
              'start_date' => '2013-10-10',
              'reason_marriage_ended' => 'Death',
              'full_name' => { 'first' => 'test', 'middle' => 'middle', 'last' => 'formerspousethree' }
            },
            {
              'end_location' => { 'location' => { 'city' => 'charlotte', 'state' => 'NC' } },
              'start_location' => { 'location' => { 'city' => 'concord', 'state' => 'NH' } },
              'end_date' => '2019-07-07',
              'start_date' => '2016-10-06',
              'reason_marriage_ended' => 'Divorce',
              'full_name' => { 'first' => 'test', 'middle' => 'middle', 'last' => 'formerspousefour' }
            }
          ],
          'spouse_marriage_history' => [
            {
              'end_location' => { 'location' => { 'city' => 'denver', 'state' => 'CO' } },
              'start_location' => { 'outside_usa' => true, 'location' => { 'city' => 'denver', 'state' => 'CO' } },
              'end_date' => '2010-07-06',
              'start_date' => '2010-03-05',
              'reason_marriage_ended' => 'Other',
              'other_reason_marriage_ended' => 'annulled',
              'full_name' => { 'first' => 'test', 'middle' => 'middle', 'last' => 'spouseformerone' }
            },
            {
              'end_location' => { 'location' => { 'city' => 'boston', 'state' => 'MA' } },
              'start_location' => { 'outside_usa' => true,
                                    'location' => { 'city' => 'fayetteville', 'state' => 'AR' } },
              'end_date' => '2013-08-08',
              'start_date' => '2011-07-12',
              'reason_marriage_ended' => 'Divorce',
              'full_name' => { 'first' => 'test', 'middle' => 'middle', 'last' => 'spouseformertwo' }
            },
            {
              'end_location' => { 'location' => { 'city' => 'portland', 'state' => 'ME' } },
              'start_location' => { 'outside_usa' => true, 'location' => { 'city' => 'washington', 'state' => 'DC' } },
              'end_date' => '2015-07-06',
              'start_date' => '2014-09-06',
              'reason_marriage_ended' => 'Death',
              'full_name' => { 'first' => 'test', 'middle' => 'middle', 'last' => 'spouseformerthree' }
            },
            {
              'end_location' => { 'location' => { 'city' => 'burlington', 'state' => 'VT' } },
              'start_location' => { 'outside_usa' => true, 'location' => { 'city' => 'wilmington', 'state' => 'DE' } },
              'end_date' => '2019-11-09',
              'start_date' => '2016-10-11',
              'reason_marriage_ended' => 'Divorce',
              'full_name' => { 'first' => 'test', 'middle' => 'middle', 'last' => 'spouseformerfour' }
            }
          ],
          'children_to_add' => [
            {
              'income_in_last_year' => true,
              'marriage_end_date' => '2023-07-03',
              'marriage_end_reason' => 'Divorce',
              'marriage_end_description' => 'short',
              'does_child_live_with_you' => false,
              'has_child_ever_been_married' => true,
              'is_biological_child_of_spouse' => false,
              'relationship_to_child' => { 'adopted' => false, 'stepchild' => false },
              'does_child_have_permanent_disability' => false,
              'is_biological_child' => true,
              'birth_location' => { 'location' => { 'city' => 'quebec', 'postal_code' => '03301',
                                                    'country' => 'CAN' } },
              'ssn' => '987654321',
              'full_name' => { 'first' => 'test', 'middle' => 'middle', 'last' => 'childone' },
              'birth_date' => '2005-01-02',
              'address' => {
                'country' => 'USA',
                'street' => '123 fake drive',
                'street2' => 'This is a really long apartment number',
                'street3' => 'line3',
                'city' => 'concord',
                'state' => 'NH',
                'postal_code' => '03301'
              },
              'living_with' => { 'first' => 'test', 'last' => 'person' },
              'does_child_have_disability' => true,
              'biological_parent_name' => { 'first' => 'bio', 'middle' => 'log', 'last' => 'cal' },
              'biological_parent_ssn' => '000000000',
              'school_age_in_school' => false
            },
            {
              'income_in_last_year' => false,
              'marriage_end_reason' => 'annulment',
              'marriage_end_description' => 'description of annulment really long text here over length 16',
              'does_child_live_with_you' => true,
              'has_child_ever_been_married' => false,
              'is_biological_child_of_spouse' => true,
              'relationship_to_child' => { 'stepchild' => true },
              'is_biological_child' => false,
              'does_child_have_permanent_disability' => true,
              'birth_location' => { 'location' => { 'state' => 'DC', 'city' => 'washington',
                                                    'postal_code' => '03301' } },
              'ssn' => '987654321',
              'full_name' => { 'first' => 'test', 'middle' => 'middle', 'last' => 'childtwo' },
              'birth_date' => '2009-04-05',
              'date_entered_household' => '2024-05-04',
              'biological_parent_name' => { 'first' => 'bio', 'middle' => 'log', 'last' => 'cal' },
              'biological_parent_ssn' => '000000000',
              'school_age_in_school' => false
            },
            {
              'marriage_end_reason' => 'annulment',
              'marriage_end_description' => 'description of annulment',
              'does_child_live_with_you' => true,
              'has_child_ever_been_married' => false,
              'relationship_to_child' => { 'adopted' => true },
              'birth_location' => { 'location' => { 'state' => 'AR', 'city' => 'bentonville',
                                                    'postal_code' => '03301' } },
              'ssn' => '987654321',
              'full_name' => { 'first' => 'test', 'middle' => 'middle', 'last' => 'childthree' },
              'birth_date' => '2010-04-06',
              'school_age_in_school' => false
            },
            {
              'income_in_last_year' => false,
              'marriage_end_reason' => 'annulment',
              'marriage_end_description' => 'description of annulment',
              'does_child_live_with_you' => true,
              'has_child_ever_been_married' => false,
              'relationship_to_child' => { 'adopted' => false },
              'is_biological_child' => true,
              'birth_location' => { 'location' => { 'state' => 'SC', 'city' => 'charleston',
                                                    'postal_code' => '03301' } },
              'ssn' => '987654321',
              'full_name' => { 'first' => 'test', 'middle' => 'middle', 'last' => 'childfour' },
              'birth_date' => '2015-09-07',
              'school_age_in_school' => false
            },
            {
              'income_in_last_year' => true,
              'marriage_end_reason' => 'annulment',
              'marriage_end_description' => 'description of annulment',
              'does_child_live_with_you' => true,
              'has_child_ever_been_married' => false,
              'relationship_to_child' => { 'adopted' => true },
              'is_biological_child' => false,
              'birth_location' => { 'location' => { 'state' => 'NH', 'city' => 'durham', 'postal_code' => '03301' } },
              'ssn' => '987654321',
              'full_name' => { 'first' => 'test', 'middle' => 'middle', 'last' => 'childfive' },
              'birth_date' => '2019-10-08',
              'school_age_in_school' => false,
              'biological_parent_name' => { 'first' => 'bio', 'middle' => 'log', 'last' => 'cal' },
              'biological_parent_ssn' => '000000000'
            },
            {
              'income_in_last_year' => false,
              'marriage_end_reason' => 'annulment',
              'marriage_end_description' => 'description of annulment',
              'does_child_live_with_you' => true,
              'has_child_ever_been_married' => false,
              'relationship_to_child' => { 'adopted' => false },
              'is_biological_child' => true,
              'birth_location' => { 'location' => { 'state' => 'NY', 'city' => 'new york', 'postal_code' => '03301' } },
              'ssn' => '987654321',
              'full_name' => { 'first' => 'test', 'middle' => 'middle', 'last' => 'childsix' },
              'birth_date' => '2023-11-07',
              'school_age_in_school' => false
            }
          ],
          'report_divorce' => {
            'spouse_income' => true,
            'date' => '2023-11-03',
            'divorce_location' => { 'location' => { 'city' => 'louisville', 'state' => 'KY', 'country' => 'US' } },
            'reason_marriage_ended' => 'Divorce',
            'full_name' => { 'first' => 'removing', 'middle' => 'former', 'last' => 'spouse' },
            'birth_date' => '1980-02-03'
          },
          'step_children' => [
            {
              'who_does_the_stepchild_live_with' => { 'first' => 'parent', 'middle' => 'middle', 'last' => 'name' },
              'living_expenses_paid' => 'More than half',
              'address' => {
                'country' => 'USA',
                'street' => '456 fake street',
                'street2' => 'this is a very long apartment number',
                'street3' => 'line3',
                'city' => 'portland',
                'state' => 'ME',
                'postal_code' => '04102'
              },
              'supporting_stepchild' => false,
              'full_name' => { 'first' => 'stepchild', 'middle' => 'middle', 'last' => 'leaving' },
              'ssn' => '987654321',
              'birth_date' => '2009-04-01'
            },
            {
              'who_does_the_stepchild_live_with' => { 'first' => 'parent', 'middle' => 'middle',
                                                      'last' => 'parentname' },
              'address' => {
                'country' => 'USA',
                'street' => '123 ocean avenue',
                'street2' => 'this is a very long apartment number',
                'street3' => 'line3',
                'city' => 'concord',
                'state' => 'NH',
                'postal_code' => '03301'
              },
              'supporting_stepchild' => false,
              'full_name' => { 'first' => 'second', 'middle' => 'middle', 'last' => 'stepchild' },
              'ssn' => '987654321',
              'birth_date' => '2009-04-01'
            }
          ],
          'deaths' => [
            {
              'deceased_dependent_income' => true,
              'dependent_death_location' => { 'location' => { 'city' => 'new orleans', 'state' => 'LA',
                                                              'country' => 'USA' } },
              'dependent_death_date' => '2024-03-02',
              'dependent_type' => 'DEPENDENT_PARENT',
              'full_name' => { 'first' => 'deceased', 'middle' => 'middle', 'last' => 'dependent' },
              'ssn' => '987654321',
              'birth_date' => '1960-01-01'
            },
            {
              'deceased_dependent_income' => true,
              'dependent_death_location' => { 'location' => { 'city' => 'new orleans', 'state' => 'LA',
                                                              'country' => 'USA' } },
              'dependent_death_date' => '2024-03-02',
              'dependent_type' => 'CHILD',
              'child_status' => { 'child_under18' => true, 'step_child' => true },
              'full_name' => { 'first' => 'deceased', 'middle' => 'middle', 'last' => 'dependent' },
              'ssn' => '987654321',
              'birth_date' => '1990-01-01'
            },
            {
              'deceased_dependent_income' => false,
              'dependent_death_location' => { 'location' => { 'city' => 'denver', 'state' => 'CO' } },
              'dependent_death_date' => '2023-10-03',
              'dependent_type' => 'SPOUSE',
              'full_name' => { 'first' => 'other', 'middle' => 'middle', 'last' => 'deceased' },
              'ssn' => '987654321',
              'birth_date' => '1960-01-01'
            }
          ],
          'child_marriage' => [{
            'dependent_income' => false,
            'date_married' => '2023-06-03',
            'full_name' => { 'first' => 'child', 'middle' => 'middle', 'last' => 'married' },
            'ssn' => '987654321',
            'birth_date' => '2008-04-05'
          }],
          'child_stopped_attending_school' => [{
            'dependent_income' => false,
            'date_child_left_school' => '2023-04-03',
            'full_name' => { 'first' => 'removing', 'middle' => 'middle', 'last' => 'child' },
            'ssn' => '987654321',
            'birth_date' => '2005-05-01'
          }]
        },
        'view:selectable686_options' => {
          'add_spouse' => true,
          'add_child' => true,
          'add_disabled_child' => true,
          'report_divorce' => true,
          'report_death' => true,
          'report_stepchild_not_in_household' => true,
          'report_marriage_of_child_under18' => true,
          'report_child18_or_older_is_not_attending_school' => true
        }
      }.to_json
    end
  end
end

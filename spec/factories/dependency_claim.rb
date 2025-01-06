# frozen_string_literal: true

FactoryBot.define do
  factory :dependency_claim, class: 'SavedClaim::DependencyClaim' do
    form_id { '686C-674' }

    form {
      {
        'view:selectable686_options': {
          add_child: true,
          report674: true
        },
        add_child: true,
        privacy_agreementAccepted: true,
        veteran_information: {
          full_name: {
            first: 'Mark',
            middle: 'A',
            last: 'Webb',
            suffix: 'Jr.'
          },
          ssn: '796104437',
          va_file_number: '796104437',
          service_number: '12345678',
          birth_date: '1950-10-04'
        },
        dependents_application: {
          veteran_information: {
            full_name: {
              first: 'Mark',
              middle: 'A',
              last: 'Webb',
              suffix: 'Jr.'
            },
            ssn: '796104437',
            va_file_number: '796104437',
            service_number: '12345678',
            birth_date: '1950-10-04'
          },
          veteran_contact_information: {
            veteran_address: {
              country_name: 'USA',
              address_line1: '8200 DOBY LN',
              city: 'PASADENA',
              stateCode: 'CA',
              zip_code: '21122'
            },
            phone_number: '1112223333',
            email_address: 'vets.gov.user+228@gmail.com'
          },
          children_to_add: [
            {
              does_child_live_with_you: false,
              child_address_info: {
                person_child_lives_with: {
                  first: 'Bill',
                  middle: 'Oliver',
                  last: 'Bradsky'
                },
                address: {
                  country_name: 'USA',
                  address_line1: '1100 Robin Cir',
                  city: 'Los Angelas',
                  state_code: 'CA',
                  zip_code: '90210'
                }
              },
              place_of_birth: {
                state: 'CA',
                city: 'Slawson'
              },
              child_status: {
                biological: true
              },
              previously_married: 'Yes',
              previous_marriage_details: {
                date_marriage_ended: '2018-03-04',
                reason_marriage_ended: 'Death'
              },
              full_name: {
                first: 'John',
                middle: 'oliver',
                last: 'Hamm',
                suffix: 'Sr.'
              },
              ssn: '370947142',
              birth_date: '2009-03-03'
            },
            {
              does_child_live_with_you: true,
              place_of_birth: {
                state: 'CA',
                city: 'Slawson'
              },
              child_status: {
                adopted: true
              },
              previously_married: 'No',
              full_name: {
                first: 'Adopted first name',
                middle: 'adopted middle name',
                last: 'adopted last name',
                suffix: 'Sr.'
              },
              ssn: '370947143',
              birth_date: '2010-03-03'
            }
          ],
          student_name_and_ssn: {
            full_name: {
              first: 'Juan',
              last: 'Barrett'
            },
            ssn: '333224444',
            birth_date: '2001-10-06'
          },
          student_address_marriage_tuition: {
            address: {
              country_name: 'USA',
              address_line1: '1900 W Olney Ave.',
              city: 'Philadelphia',
              state_code: 'PA',
              zip_code: '19141'
            },
            was_married: false,
            tuition_is_paid_by_gov_agency: false
          },
          program_information: {
            student_is_enrolled_full_time: true
          },
          school_information: {
            name: 'University of Pennsylvania',
            address: {
              country_name: 'USA',
              address_line1: '4201 Henry Ave',
              city: 'Philadelphia',
              state_code: 'PA',
              zip_code: '19144'
            }
          },
          student_did_attend_school_last_term: false
        }
      }.to_json
    }
  end
  factory :dependency_claim_674_only, class: 'SavedClaim::DependencyClaim' do
    form_id { '686C-674' }

    form {
      {
        'view:selectable686_options': {
          report674: true
        },
        add_child: false,
        privacy_agreementAccepted: true,
        veteran_information: {
          full_name: {
            first: 'Mark',
            middle: 'A',
            last: 'Webb',
            suffix: 'Jr.'
          },
          ssn: '796104437',
          va_file_number: '796104437',
          service_number: '12345678',
          birth_date: '1950-10-04'
        },
        dependents_application: {
          veteran_information: {
            full_name: {
              first: 'Mark',
              middle: 'A',
              last: 'Webb',
              suffix: 'Jr.'
            },
            ssn: '796104437',
            va_file_number: '796104437',
            service_number: '12345678',
            birth_date: '1950-10-04'
          },
          veteran_contact_information: {
            veteran_address: {
              country_name: 'USA',
              address_line1: '8200 DOBY LN',
              city: 'PASADENA',
              stateCode: 'CA',
              zip_code: '21122'
            },
            phone_number: '1112223333',
            email_address: 'vets.gov.user+228@gmail.com'
          },
          student_name_and_ssn: {
            full_name: {
              first: 'Juan',
              last: 'Barrett'
            },
            ssn: '333224444',
            birth_date: '2001-10-06'
          },
          student_address_marriage_tuition: {
            address: {
              country_name: 'USA',
              address_line1: '1900 W Olney Ave.',
              city: 'Philadelphia',
              state_code: 'PA',
              zip_code: '19141'
            },
            was_married: false,
            tuition_is_paid_by_gov_agency: false
          },
          program_information: {
            student_is_enrolled_full_time: true
          },
          school_information: {
            name: 'University of Pennsylvania',
            address: {
              country_name: 'USA',
              address_line1: '4201 Henry Ave',
              city: 'Philadelphia',
              state_code: 'PA',
              zip_code: '19144'
            }
          },
          student_did_attend_school_last_term: false
        }
      }.to_json
    }
  end
end

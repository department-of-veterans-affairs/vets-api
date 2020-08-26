# frozen_string_literal: true

FactoryBot.define do
  factory :dependency_claim, class: SavedClaim::DependencyClaim do
    form_id { '686C-674' }

    form {
      {
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
          veteran_contact_information: {
            veteran_address: {
              country_name: 'USA',
              address_line1: '8200 DOBY LN',
              city: 'PASADENA',
              stateCode: 'CA',
              zipCode: '21122'
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
          ]
        }
      }.to_json
    }
  end
end

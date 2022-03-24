# frozen_string_literal: true

FactoryBot.define do
  factory :in_progress_form do
    user_uuid { SecureRandom.uuid }
    form_id { 'edu_benefits' }
    metadata do
      {
        version: 1,
        return_url: 'foo.com'
      }
    end
    trait :with_nested_metadata do
      metadata do
        {
          version: 1,
          returnUrl: 'foo.com',
          howNow: {
            'brown-cow' => {
              '-an eas-i-ly corRupted KEY.' => true
            }
          }
        }
      end
    end
    form_data do
      {
        chapter1606: true,
        veteranFullName: {
          first: 'Mark',
          last: 'Olson'
        },
        gender: 'M',
        veteranDateOfBirth: '1985-03-07',
        veteranSocialSecurityNumber: '111223333',
        veteranAddress: {
          country: 'USA',
          state: 'WI',
          postalCode: '53130',
          street: '123 Main St',
          city: 'Milwaukee'
        },
        homePhone: '5551110000',
        secondaryContact: {
          fullName: 'Sibling Olson',
          sameAddress: true
        },
        bankAccount: {
          accountType: 'checking',
          bankName: 'First Bank of JSON',
          routingNumber: '123456789',
          accountNumber: '88888888888'
        },
        school: {
          name: 'FakeData University',
          address: {
            country: 'USA',
            state: 'MD',
            postalCode: '21231',
            street: '111 Uni Drive',
            city: 'Baltimore'
          },
          startDate: '2016-08-29',
          educationalObjective: '...'
        },
        educationType: 'college',
        postHighSchoolTrainings: [
          {
            name: 'OtherCollege Name',
            dateRange: {
              from: '1999-01-01',
              to: '2000-01-01'
            },
            city: 'New York',
            hours: 8,
            hoursType: 'semester',
            state: 'NY',
            degreeReceived: 'BA',
            major: 'History'
          }
        ],
        currentlyActiveDuty: {
          yes: false,
          onTerminalLeave: false,
          nonVaAssistance: false
        },
        highSchoolOrGedCompletionDate: '2010-06-06',
        additionalContributions: false,
        activeDutyKicker: false,
        reserveKicker: false,
        serviceBefore1977: {
          married: true,
          haveDependents: true,
          parentDependent: false
        },
        toursOfDuty: [
          {
            dateRange: {
              from: '2001-01-01',
              to: '2010-10-10'
            },
            serviceBranch: 'Army',
            serviceStatus: 'Active Duty',
            involuntarilyCalledToDuty: 'yes'
          },
          {
            dateRange: {
              from: '1995-01-01',
              to: '1998-10-10'
            },
            serviceBranch: 'Army',
            serviceStatus: 'Honorable Discharge',
            involuntarilyCalledToDuty: 'yes'
          }
        ],
        faaFlightCertificatesInformation: 'cert1, cert2',
        privacyAgreementAccepted: true
      }.to_json
    end

    factory :in_progress_update_form do
      form_data do
        {
          chapter1606: true,
          veteranFullName: {
            first: 'Mark',
            last: 'Olson'
          },
          gender: 'M',
          veteranDateOfBirth: '1985-03-07',
          veteranSocialSecurityNumber: '111223333',
          veteranAddress: {
            country: 'USA',
            state: 'CA',
            postalCode: '90210',
            street: 'Sunset Blvd',
            city: 'Beverly Hills'
          },
          homePhone: '3101112222',
          secondaryContact: {
            fullName: 'Sibling Olson',
            sameAddress: true
          },
          bankAccount: {
            accountType: 'checking',
            bankName: 'First Bank of JSON',
            routingNumber: '123456789',
            accountNumber: '88888888888'
          },
          school: {
            name: 'FakeData University',
            address: {
              country: 'USA',
              state: 'MD',
              postalCode: '21231',
              street: '111 Uni Drive',
              city: 'Baltimore'
            },
            startDate: '2016-08-29',
            educationalObjective: '...'
          },
          educationType: 'college',
          postHighSchoolTrainings: [
            {
              name: 'OtherCollege Name',
              dateRange: {
                from: '1999-01-01',
                to: '2000-01-01'
              },
              city: 'New York',
              hours: 8,
              hoursType: 'semester',
              state: 'NY',
              degreeReceived: 'BA',
              major: 'History'
            }
          ],
          currentlyActiveDuty: {
            yes: false,
            onTerminalLeave: false,
            nonVaAssistance: false
          },
          highSchoolOrGedCompletionDate: '2010-06-06',
          additionalContributions: false,
          activeDutyKicker: false,
          reserveKicker: false,
          serviceBefore1977: {
            married: true,
            haveDependents: true,
            parentDependent: false
          },
          toursOfDuty: [
            {
              dateRange: {
                from: '2001-01-01',
                to: '2010-10-10'
              },
              serviceBranch: 'Army',
              serviceStatus: 'Active Duty',
              involuntarilyCalledToDuty: 'yes'
            },
            {
              dateRange: {
                from: '1995-01-01',
                to: '1998-10-10'
              },
              serviceBranch: 'Army',
              serviceStatus: 'Honorable Discharge',
              involuntarilyCalledToDuty: 'yes'
            }
          ],
          faaFlightCertificatesInformation: 'cert1, cert2',
          privacyAgreementAccepted: true
        }.to_json
      end
    end

    factory :in_progress_526_form do
      user_uuid { SecureRandom.uuid }
      form_id { '21-526EZ' }
      metadata do
        {
          version: 1,
          returnUrl: 'foo.com'
        }
      end
      form_data do
        {
          'veteran' => {
            'phone_email_card' => {
              'primary_phone' => '7779998888',
              'email_address' => 'me@foo.com'
            },
            'mailing_address' => {
              'country' => 'USA',
              'address_line1' => '123 Main St.',
              'city' => 'Costa Mesa',
              'state' => 'CA',
              'zip_code' => '92626'
            },
            'view:contact_info_description' => {},
            'homelessness' => {}
          },
          'privacy_agreement_accepted' => false,
          'view:military_history_note' => {},
          'obligation_term_of_service_date_range' => {},
          'view:disabilities_clarification' => {},
          'standard_claim' => false,
          'view:fdc_warning' => {}
        }.to_json
      end
    end

    factory :in_progress_686c_form do
      user_uuid { SecureRandom.uuid }
      form_id { '686C-674' }
      metadata do
        {
          version: 1,
          returnUrl: 'foo.com'
        }
      end
      form_data do
        {
          'view:selectable686_options' => { 'add_spouse' => false },
          'view:686_information' => {},
          'veteran_information' =>
           {
             'full_name' => { 'first' => 'first_name', 'middle' => 'J', 'last' => 'last_name' },
             'ssn' => '111223333',
             'birth_date' => '1985-03-07'
           }
        }.to_json
      end
    end
  end
end

# frozen_string_literal: true
FactoryBot.define do
  factory :in_progress_form do
    user_uuid { SecureRandom.uuid }
    form_id 'edu_benefits'
    metadata(
      version: 1,
      return_url: 'foo.com'
    )
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
  end
end

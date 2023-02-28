# frozen_string_literal: true

FactoryBot.define do
  factory :va1990, class: 'SavedClaim::EducationBenefits::VA1990', parent: :education_benefits do
    form do
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
        educationProgram: {
          name: 'FakeData University',
          address: {
            country: 'USA',
            state: 'MD',
            postalCode: '21231',
            street: '111 Uni Drive',
            city: 'Baltimore'
          },
          educationType: 'college'
        },
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

    factory :va1990_chapter33, class: 'SavedClaim::EducationBenefits::VA1990', parent: :education_benefits do
      form {
        {
          email: 'email@example.com',
          chapter33: true,
          veteranSocialSecurityNumber: '111223333',
          veteranFullName: {
            first: 'Mark',
            last: 'Olson'
          },
          privacyAgreementAccepted: true
        }.to_json
      }
    end

    factory :va1990_with_relinquished, class: 'SavedClaim::EducationBenefits::VA1990', parent: :education_benefits do
      form {
        {
          email: 'email@example.com',
          chapter33: true,
          chapter1606: true,
          chapter32: true,
          benefitsRelinquished: 'chapter30',
          veteranSocialSecurityNumber: '111223333',
          veteranFullName: {
            first: 'Mark',
            last: 'Olson'
          },
          privacyAgreementAccepted: true
        }.to_json
      }
    end

    factory :va1990_with_custom_form do
      transient do
        custom_form {}
      end

      after(:build) do |va1990, evaluator|
        va1990.form = JSON.parse(va1990.form).merge(evaluator.custom_form).to_json
      end

      factory :va1990_western_region do
        custom_form {
          {
            'educationProgram' => {
              'address' => {
                'country' => 'USA',
                'state' => 'CA',
                'postalCode' => '90212',
                'street' => '111 Uni Drive',
                'city' => 'Los Angeles'
              }
            }
          }
        }
      end
    end
  end
end

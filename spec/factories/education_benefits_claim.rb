# frozen_string_literal: true
FactoryGirl.define do
  factory :education_benefits_claim do
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
          sameAddressAndPhone: true
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
        # rubocop:disable LineLength
        remarks: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Proin sit amet ullamcorper est, in interdum velit. Cras purus orci, varius eget efficitur nec, dapibus id risus. Donec in pellentesque enim. Proin sagittis, elit nec consequat malesuada, nibh justo luctus enim, ac aliquet lorem orci vel neque. Ut eget accumsan ipsum. Cras sed venenatis massa. Duis odio urna, laoreet quis ante sed, facilisis congue purus. Etiam semper facilisis luctus. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Etiam blandit eget nibh at ornare. Sed non porttitor dui. Proin ornare magna diam, ut lacinia magna accumsan euismod.

        Phasellus et nisl id lorem feugiat molestie. Aliquam molestie,
        nulla eu fringilla finibus, massa lectus varius quam, quis ornare
        sem lorem lacinia dui. Integer consequat non arcu convallis mollis.
        Vivamus magna turpis, pharetra non eros at, feugiat rutrum nisl.
        Maecenas eros tellus, blandit id libero sed, imperdiet fringilla
        eros. Nulla vel tortor vel neque fermentum laoreet id vitae ex.
        Mauris posuere lorem tellus. Pellentesque at augue arcu.
        Vestibulum aliquam urna ac est lacinia, eu congue nisi tempor.
        ",
        # rubocop:enable LineLength
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
        faaFlightCertificatesInformation: 'cert1, cert2'
      }.to_json
    end

    factory :education_benefits_claim_with_custom_form do
      transient do
        custom_form {}
      end

      after(:build) do |education_benefits_claim, evaluator|
        education_benefits_claim.form = JSON.parse(education_benefits_claim.form).merge(evaluator.custom_form).to_json
      end

      factory :education_benefits_claim_western_region do
        custom_form(
          'school' => {
            'address' => {
              'country' => 'USA',
              'state' => 'CA',
              'postalCode' => '90212',
              'street' => '111 Uni Drive',
              'city' => 'Los Angeles'
            }
          }
        )
      end
    end
  end
end

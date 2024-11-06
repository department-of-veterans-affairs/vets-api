# frozen_string_literal: true

FactoryBot.define do
  factory :secondary_appeal_form4142, class: 'SecondaryAppealForm' do
    guid { SecureRandom.uuid }
    form_id { '21-4142' }
    form do
      {
        veteran: {
          fullName: {
            first: 'Person',
            last: 'McPerson'
          },
          dateOfBirth: '1983-01-23',
          ssn: '111223333',
          address: {},
          homePhone: '123-456-7890'
        },
        patientIdentification: {
          isRequestingOwnMedicalRecords: true

        },
        providerFacility: [{
          providerFacilityName: 'provider 1',
          treatmentDateRange: [
            {
              from: '1980-1-1',
              to: '1985-1-1'
            },
            {
              from: '1986-1-1',
              to: '1987-1-1'
            }
          ],
          providerFacilityAddress: {
            street: '123 Main Street',
            street2: '1B',
            city: 'Baltimore',
            state: 'MD',
            country: 'USA',
            postalCode: '21200-1111'
          }
        }],
        preparerIdentification: {
          relationshipToVeteran: 'self'
        },
        acknowledgeToReleaseInformation: true,
        limitedConsent: 'some string',
        privacyAgreementAccepted: true
      }.to_json
    end
    delete_date { nil }
    appeal_submission
  end
end
